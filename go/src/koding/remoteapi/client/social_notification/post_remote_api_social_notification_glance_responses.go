package social_notification

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the swagger generate command

import (
	"fmt"
	"io"

	"github.com/go-openapi/runtime"

	strfmt "github.com/go-openapi/strfmt"

	"koding/remoteapi/models"
)

// PostRemoteAPISocialNotificationGlanceReader is a Reader for the PostRemoteAPISocialNotificationGlance structure.
type PostRemoteAPISocialNotificationGlanceReader struct {
	formats strfmt.Registry
}

// ReadResponse reads a server response into the received o.
func (o *PostRemoteAPISocialNotificationGlanceReader) ReadResponse(response runtime.ClientResponse, consumer runtime.Consumer) (interface{}, error) {
	switch response.Code() {

	case 200:
		result := NewPostRemoteAPISocialNotificationGlanceOK()
		if err := result.readResponse(response, consumer, o.formats); err != nil {
			return nil, err
		}
		return result, nil

	case 401:
		result := NewPostRemoteAPISocialNotificationGlanceUnauthorized()
		if err := result.readResponse(response, consumer, o.formats); err != nil {
			return nil, err
		}
		return nil, result

	default:
		return nil, runtime.NewAPIError("unknown error", response, response.Code())
	}
}

// NewPostRemoteAPISocialNotificationGlanceOK creates a PostRemoteAPISocialNotificationGlanceOK with default headers values
func NewPostRemoteAPISocialNotificationGlanceOK() *PostRemoteAPISocialNotificationGlanceOK {
	return &PostRemoteAPISocialNotificationGlanceOK{}
}

/*PostRemoteAPISocialNotificationGlanceOK handles this case with default header values.

Request processed successfully
*/
type PostRemoteAPISocialNotificationGlanceOK struct {
	Payload *models.DefaultResponse
}

func (o *PostRemoteAPISocialNotificationGlanceOK) Error() string {
	return fmt.Sprintf("[POST /remote.api/SocialNotification.glance][%d] postRemoteApiSocialNotificationGlanceOK  %+v", 200, o.Payload)
}

func (o *PostRemoteAPISocialNotificationGlanceOK) readResponse(response runtime.ClientResponse, consumer runtime.Consumer, formats strfmt.Registry) error {

	o.Payload = new(models.DefaultResponse)

	// response payload
	if err := consumer.Consume(response.Body(), o.Payload); err != nil && err != io.EOF {
		return err
	}

	return nil
}

// NewPostRemoteAPISocialNotificationGlanceUnauthorized creates a PostRemoteAPISocialNotificationGlanceUnauthorized with default headers values
func NewPostRemoteAPISocialNotificationGlanceUnauthorized() *PostRemoteAPISocialNotificationGlanceUnauthorized {
	return &PostRemoteAPISocialNotificationGlanceUnauthorized{}
}

/*PostRemoteAPISocialNotificationGlanceUnauthorized handles this case with default header values.

Unauthorized request
*/
type PostRemoteAPISocialNotificationGlanceUnauthorized struct {
	Payload *models.UnauthorizedRequest
}

func (o *PostRemoteAPISocialNotificationGlanceUnauthorized) Error() string {
	return fmt.Sprintf("[POST /remote.api/SocialNotification.glance][%d] postRemoteApiSocialNotificationGlanceUnauthorized  %+v", 401, o.Payload)
}

func (o *PostRemoteAPISocialNotificationGlanceUnauthorized) readResponse(response runtime.ClientResponse, consumer runtime.Consumer, formats strfmt.Registry) error {

	o.Payload = new(models.UnauthorizedRequest)

	// response payload
	if err := consumer.Consume(response.Body(), o.Payload); err != nil && err != io.EOF {
		return err
	}

	return nil
}
