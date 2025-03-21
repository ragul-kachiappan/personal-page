+++
title = "Custom Validations in Django Rest Framework"
date = 2025-03-21
draft = "false"
tags = ["Python", "Django", "DRF"]
categories = ["Python", "Django"]
+++

One of the key components of http request-response is request data validation. Modern HTTP requests would typically send a JSON payload that needs to be sanitized, validated before we go about doing further business logic and database operations.
Typically the client side will implement basic form validations when it uses something like [formik](https://formik.org/docs/guides/validation). But backend should always cover all validations as a security precaution.
This [article](https://eaton-works.com/2024/12/19/mcdelivery-india-hack/) on hacking Mcdonald's India Service APIs showcased some interesting vulnerabilities that can be exploited with broken backend validations and authorizations.

Django REST Framework provides opinionated ways to build modern Web APIs on top of robust Django architecture. Django's batteries included approach along with DRF's modern REST API conveniences allows developers to perform rapid development of Backend APIs.
One of the core components of DRF is the concept of serializers. My understanding is serializers allows easy mapping of data between request/response payload and database. We can also take care of any necessary validations and transformations in serializers which allows for clean separations of steps in request/response handling. There are criticisms against serializers on performance and modern type hint based approach from FastAPI. But it's still reliable and straightforward to implement.

Let's a consider a common example of defining Signup API. Client side will collect some required details from a form and send it via a POST request.

```python

class SignupView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return response.Response(serializer.data, status=status.HTTP_201_CREATED)
        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

```


```python

class UserSerializer(serializers.ModelSerializer):
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['email', 'username', 'password', 'phone_number', 'password_confirm']
        extra_kwargs = {'password': {'write_only': True}}

```

## Custom Validations

DRF will provide some basic validations such as `required` but more often we would have custom validation requirements for each field and custom way to respond.
We have some ways to define our own validation logic inside serializers.

### Field level Validations

```python

def validate_phone_number(self, value):
    if not value:
        raise serializers.ValidationError("Phone number is required")
    if not value.isdigit():
        raise serializers.ValidationError("Phone number must contain only digits")
    if len(value) < 10 or len(value) > 15:
        raise serializers.ValidationError("Phone number must be between 10 and 15 digits")
    return value

```
### override `validate` method

```python

def validate(self, data):
    # Check if email domain is allowed
    email = data.get('email')
    domain = email.split('@')[1]

    if domain in BLACKLISTED_DOMAINS:
        raise serializers.ValidationError("Email domain not allowed")

    # Check if username contains inappropriate words
    if any(word in data.get('username').lower() for word in INAPPROPRIATE_WORDS):
        raise serializers.ValidationError("Username contains inappropriate content")

    return data

```
A standard DRF error response looks like:

```json
{
    "field_name": [
        "Error message"
    ]
}
```

Or for non-field errors:

```json
{
    "non_field_errors": [
        "Error message"
    ]
}
```

So far its all and well and good. But in a structured project where teams might have their own internal style guide, you may need further customizations to conform to the specified response formats.
For example, one of the projects I worked with had a style guide where all validation error responses should be of the following format.
```json
{
    "result": false,
    "message": "Error message",
}
```
`ValidationError` does accept dictionary. So we could provide errors like
```python
raise serializers.ValidationError(
    {
        "result": False,
        "message": "phone number is required",
    }
)
```
But the output would look like
```python
{
    "result": [
        "False"
    ],
    "message": [
        "phone number is required"
    ]
}
```


Note that `ValidationError` has done some automatic list conversions and string coercion.
Oddly, if you try to use `ValidationError` outside serializers, you would get string transformations but not list conversions
```python
{
    "result": "False",
    "message": "phone number is required"
}
```
This is an unexpected quirk of ValidationError implementation.

## How Serializer Field Validation Works

DRF has a built-in validation pipeline that executes in this order:
1. Field-level validation (e.g., required fields, data types)
2. Object-level validation (via `.validate()` method)
3. Model validation when saving

When validation fails, DRF raises a `ValidationError`:

```python
class ValidationError(APIException):
    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = _('Invalid input.')
    default_code = 'invalid'

    def __init__(self, detail=None, code=None):
        if detail is None:
            detail = self.default_detail
        if code is None:
            code = self.default_code

        # For validation failures, we may collect many errors together,
        # so the details should always be coerced to a list if not already.
        if isinstance(detail, tuple):
            detail = list(detail)
        elif not isinstance(detail, dict) and not isinstance(detail, list):
            detail = [detail]

        self.detail = _get_error_details(detail, code)
```
You can see a peculiar `_get_error_details`. Here are the internal implementations.

```python
def _get_error_details(data, default_code=None):
    """
    Descend into a nested data structure, forcing any
    lazy translation strings or strings into `ErrorDetail`.
    """
    if isinstance(data, (list, tuple)):
        ret = [
            _get_error_details(item, default_code) for item in data
        ]
        if isinstance(data, ReturnList):
            return ReturnList(ret, serializer=data.serializer)
        return ret
    elif isinstance(data, dict):
        ret = {
            key: _get_error_details(value, default_code)
            for key, value in data.items()
        }
        if isinstance(data, ReturnDict):
            return ReturnDict(ret, serializer=data.serializer)
        return ret

    text = force_str(data)
    code = getattr(data, 'code', default_code)
    return ErrorDetail(text, code)

def force_str(s, encoding="utf-8", strings_only=False, errors="strict"):
    """
    Similar to smart_str(), except that lazy instances are resolved to
    strings, rather than kept as lazy objects.

    If strings_only is True, don't convert (some) non-string-like objects.
    """
    # Handle the common case first for performance reasons.
    if issubclass(type(s), str):
        return s
    if strings_only and is_protected_type(s):
        return s
    try:
        if isinstance(s, bytes):
            s = str(s, encoding, errors)
        else:
            s = str(s)
    except UnicodeDecodeError as e:
        raise DjangoUnicodeDecodeError(*e.args) from None
    return s
```

DRF's validation errors require error response to be of format of `ErrorDetail` which is a Subclass of `str` type and we end up with unexpected string transformations and list conversions.

There are few ways to overcome this problem and conform to a custom style guide.

## Solution 1: Custom ValidationError implementation.
```python
class CustomValidationError(APIException):
    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = {"result": False, "msg": "Validation Error"}
    default_code = "validation_error"

    def __init__(self, detail=None, code=None):
        if detail:
            self.default_detail = detail
        self.detail = self.default_detail
        if code is None:
            code = self.default_code

```
```python
raise CustomValidationError(
    {
        "result": False,
        "message": "phone number is required",
    }
)
```
This will override the default behaviours and lets us specify our own response format.

## Solution 2: Custom exception handler
DRF [docs](https://www.django-rest-framework.org/api-guide/exceptions/#custom-exception-handling) recommends having a custom exception handler if we need to follow a global uniform style guide.

```python
def custom_exception_handler(exc, context):
    # Call default handler first
    response = exception_handler(exc, context)

    # If it's already handled
    if response is not None:
        # Transform the response structure if needed
        if isinstance(response.data, dict):
            errors = {}
            for field, detail in response.data.items():
                if isinstance(detail, list):
                    errors[field] = detail
                else:
                    errors[field] = [str(detail)]

            response.data = {
                'success': False,
                'errors': errors,
                'message': 'Validation failed'
            }

    return response
```

Then register it in settings:

```python
REST_FRAMEWORK = {
    'EXCEPTION_HANDLER': 'myapp.utils.custom_exception_handler'
}
```
You can even use this to log errors to a log file or cloud monitoring tools.

## Solution 3: Plain if/else
We can completely avoid validations in serializers and just do our own validation helper with series of if/else logic.
```python
class SignupView(views.APIView):
    def post(self, request):
        data = request.data
        if len(data['password']) < 8:
            return response.Response(
                {'password': 'Password must be at least 8 characters'},
                status=status.HTTP_400_BAD_REQUEST
            )
        if not data['phone_number'].isdigit():
            return response.Response(
                {'phone_number': 'Phone number must contain only digits'},
                status=status.HTTP_400_BAD_REQUEST
            )
        # More validation...
        # Actually create user...
```
This is more simple and would actually helpful if we are working with a team with limited Django-DRF experience.
But this would be an anti-pattern that goes against opinionated ways of Django.


## Solution 4: The Pydantic Approach

If you're willing to deviate from DRF conventions, Pydantic offers powerful validation:
But this suggestion is mostly experimental. At this stage, you are better off adopting FastAPI.

```python
from pydantic import BaseModel, validator, EmailStr

class UserSchema(BaseModel):
    email: EmailStr
    username: str
    password: str
    password_confirm: str

    @validator('password_confirm')
    def passwords_match(cls, v, values):
        if 'password' in values and v != values['password']:
            raise ValueError("Passwords don't match")
        return v

    @validator('email')
    def validate_email_domain(cls, v):
        domain = v.split('@')[1]
        if domain in BLACKLISTED_DOMAINS:
            raise ValueError("Email domain not allowed")
        return v
```

Then use it with DRF:
```python
class SignupView(views.APIView):
    def post(self, request):
        data = request.data
        try:
            user_data = UserSchema(**data)
            # Continue with validated data
            return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)
        except ValidationError as e:
            return Response(
                {
                "result": False,
                "message": e.errors(),
                },
                status=status.HTTP_400_BAD_REQUEST
            )
```
---
## Conclusion

Django-DRF allows us to be rapid and robust but it's has some limitations on flexibility on adopting the framework for our use cases.
I have gone through some ways we can implement custom validations while still taking advantage of other perks in DRF.

I would recommend a custom exception handler for global specification and custom ValidationError for specific cases.
If/else would work too but beware of code structure spiralling out of control.
Choose based on your project's needs, team familiarity, and how much you value consistency versus flexibility.

## References
- [Django Rest Framework serializers](https://www.django-rest-framework.org/api-guide/serializers/)
- [Django Rest Framework exceptions](https://www.django-rest-framework.org/api-guide/exceptions/#exceptions)
- [DRF ValidationError source code](https://github.com/encode/django-rest-framework/blob/73cbb9cd4acd36f859d9f656b8f134c9d2a754f3/rest_framework/exceptions.py#L143)
