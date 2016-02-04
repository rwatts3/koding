package command

import (
	"encoding/json"
	"errors"
	"sort"
	"time"

	"koding/db/models"
	"koding/db/mongodb/modelhelper"
	"koding/kites/kloud/machinestate"
	"koding/kites/kloud/sshutil"

	"github.com/koding/kite/protocol"
	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"
)

type Template struct {
	Machines struct {
		Labels map[string]struct{} `json:"vagrantkite_build"`
	} `json:"resource"`
}

func machineLabels(template []byte) ([]string, error) {
	var t Template
	if err := json.Unmarshal(template, &t); err != nil {
		return nil, err
	}
	var labels []string
	for label := range t.Machines.Labels {
		labels = append(labels, label)
	}
	if len(labels) == 0 {
		return nil, errors.New("no instance definitions found")
	}
	sort.Strings(labels)
	return labels, nil
}

func CreateUser(opts *UserOptions) (*User, error) {
	username := opts.Username
	groupname := opts.Groupname
	provider := opts.Provider
	template := opts.Template

	privateKey, publicKey, err := sshutil.TemporaryKey()
	if err != nil {
		return nil, err
	}

	labels, err := machineLabels([]byte(template))
	if err != nil {
		return nil, err
	}

	db := modelhelper.Mongo
	relationExists := true

	// jAccounts
	var account models.Account
	err = db.Run("jAccounts", func(c *mgo.Collection) error {
		return c.Find(bson.M{"profile.nickname": username}).One(&account)
	})
	if err == mgo.ErrNotFound {
		relationExists = false

		account = models.Account{
			Id: bson.NewObjectId(),
			Profile: models.AccountProfile{
				Nickname: username,
			},
		}

		err = db.Run("jAccounts", func(c *mgo.Collection) error {
			return c.Insert(&account)
		})
	}
	if err != nil {
		return nil, errors.New("failure looking up jAccounts: " + err.Error())
	}

	// jGroups
	var group models.Group
	err = db.Run("jGroups", func(c *mgo.Collection) error {
		return c.Find(bson.M{"slug": groupname}).One(&group)
	})
	if err == mgo.ErrNotFound {
		relationExists = false

		group = models.Group{
			Id:    bson.NewObjectId(),
			Title: groupname,
			Slug:  groupname,
		}
		err = db.Run("jGroups", func(c *mgo.Collection) error {
			return c.Insert(&group)
		})
	}
	if err != nil {
		return nil, errors.New("failure looking up jGroups: " + err.Error())
	}

	if !relationExists {
		// add relation between use and group
		relationship := &models.Relationship{
			Id:         bson.NewObjectId(),
			TargetId:   account.Id,
			TargetName: "JAccount",
			SourceId:   group.Id,
			SourceName: "JGroup",
			As:         "member",
		}

		if err := db.Run("relationships", func(c *mgo.Collection) error {
			return c.Insert(&relationship)
		}); err != nil {
			return nil, errors.New("failure insering relationship: " + err.Error())
		}
	}

	// jUsers
	var user models.User
	err = db.Run("jUsers", func(c *mgo.Collection) error {
		return c.Find(bson.M{"username": username}).One(&user)
	})
	if err == nil && len(user.SshKeys) != 0 {
		publicKey = user.SshKeys[0].Key
	}
	if err == mgo.ErrNotFound {
		user = models.User{
			ObjectId:      bson.NewObjectId(),
			Email:         username + "@" + username + ".com",
			LastLoginDate: time.Now().UTC(),
			RegisteredAt:  time.Now().UTC(),
			Name:          username, // bson equivelant is username
			Password:      "somerandomnumbers",
			Status:        "confirmed",
			SshKeys: []struct {
				Title string `bson:"title"`
				Key   string `bson:"key"`
			}{
				{Key: publicKey},
			},
		}

		err = db.Run("jUsers", func(c *mgo.Collection) error {
			return c.Insert(&user)
		})
	}
	if err != nil {
		return nil, errors.New("failure looking up jUsers: " + err.Error())
	}

	queryString := protocol.Kite{ID: opts.KlientID}.String()

	cred := &models.Credential{
		Id:         bson.NewObjectId(),
		Provider:   opts.Provider,
		Identifier: bson.NewObjectId().Hex(),
		OriginId:   account.Id,
	}

	credData := &models.CredentialData{
		Id:         bson.NewObjectId(),
		Identifier: cred.Identifier,
		OriginId:   account.Id,
		Meta: bson.M{
			"queryString": queryString,
			"memory":      0,
			"cpu":         0,
			"box":         "",
		},
	}

	if err := modelhelper.InsertCredential(cred, credData); err != nil {
		return nil, err
	}

	relationship := &models.Relationship{
		Id:         bson.NewObjectId(),
		TargetId:   cred.Id,
		TargetName: "JCredential",
		SourceId:   account.Id,
		SourceName: "JAccount",
		As:         "owner",
	}

	if err := db.Run("relationships", func(c *mgo.Collection) error {
		return c.Insert(relationship)
	}); err != nil {
		return nil, err
	}

	// jComputeStack and jStackTemplates
	stackTemplateId := bson.NewObjectId()
	stackTemplate := &models.StackTemplate{
		Id: stackTemplateId,
		Credentials: map[string][]string{
			"vagrant": {cred.Identifier},
		},
	}
	stackTemplate.Template.Content = template

	if err := db.Run("jStackTemplates", func(c *mgo.Collection) error {
		return c.Insert(&stackTemplate)
	}); err != nil {
		return nil, err
	}

	// later we can add more users with "Owner:false" to test sharing capabilities
	users := []models.MachineUser{
		{Id: user.ObjectId, Sudo: true, Owner: true},
	}

	machineIds := make([]bson.ObjectId, len(labels))

	for i, label := range labels {
		machineId := bson.NewObjectId()
		machine := &models.Machine{
			ObjectId:   machineId,
			Label:      label,
			Domain:     username + ".dev.koding.io",
			Provider:   provider,
			CreatedAt:  time.Now().UTC(),
			Users:      users,
			Meta:       make(bson.M, 0),
			Groups:     make([]models.MachineGroup, 0),
			Credential: username,
		}

		machine.Assignee.InProgress = false
		machine.Assignee.AssignedAt = time.Now().UTC()
		machine.Status.State = machinestate.NotInitialized.String()
		machine.Status.ModifiedAt = time.Now().UTC()

		machineIds[i] = machine.ObjectId

		if err := db.Run("jMachines", func(c *mgo.Collection) error {
			return c.Insert(&machine)
		}); err != nil {
			return nil, err
		}
	}

	computeStackID := bson.NewObjectId()
	computeStack := &models.ComputeStack{
		Id:          computeStackID,
		BaseStackId: stackTemplateId,
		Machines:    machineIds,
	}

	if err := db.Run("jComputeStacks", func(c *mgo.Collection) error {
		return c.Insert(&computeStack)
	}); err != nil {
		return nil, err
	}

	return &User{
		MachineIDs:      machineIds,
		MachineLabels:   labels,
		StackID:         computeStackID.Hex(),
		StackTemplateID: stackTemplate.Id.Hex(),
		AccountID:       account.Id,
		CredID:          cred.Id.Hex(),
		CredDataID:      credData.Id.Hex(),
		PrivateKey:      privateKey,
		PublicKey:       publicKey,
		Identifiers:     []string{cred.Identifier},
	}, nil
}
