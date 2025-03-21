+++
title = "Custom Validations in Django Rest Framework"
date = 2025-03-21
draft = "false"
tags = ["Python", "Django", "DRF"]
categories = ["Python", "Django"]
+++

## Introduction

One of the key components of HTTP request-response is request data validation. Modern HTTP requests typically send a JSON payload that needs to be sanitized and validated before proceeding with business logic and database operations.

While client-side applications may implement basic form validations using libraries like [Formik](https://formik.org/docs/guides/validation), backend validation remains essential as a security precaution. This [article](https://eaton-works.com/2024/12/19/mcdelivery-india-hack/) on hacking McDonald's India Service APIs showcases interesting vulnerabilities that can be exploited when backend validations and authorizations are improperly implemented.

Django REST Framework (DRF) provides opinionated ways to build modern Web APIs on top of Django's robust architecture. Django's "batteries included" approach, combined with DRF's REST API conveniences, allows developers to rapidly develop backend APIs.

## Serializers in Django REST Framework

One of the core components of DRF is the concept of serializers. Serializers facilitate easy mapping of data between request/response payloads and database models. They also handle necessary validations and transformations, allowing for clean separation of concerns in request/response handling. While there are criticisms regarding serializers' performance compared to modern type hint-based approaches like FastAPI, they remain reliable and straightforward to implement.

Let's consider a common example: defining a Signup API. The client collects required details from a form and sends them via a POST request:

```python
class SignupView(views.APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return response.Response(
                serializer.data, status=status.HTTP_201_CREATED
            )
        return response.Response(
            serializer.errors, status=status.HTTP_400_BAD_REQUEST
        )
```

And here's the corresponding serializer:

```python
class UserSerializer(serializers.ModelSerializer):
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            "email",
            "username",
            "password",
            "phone_number",
            "password_confirm",
        ]
        extra_kwargs = {"password": {"write_only": True}}
```

## Custom Validations

DRF provides basic validations such as `required`, but often we need custom validation requirements for specific fields and customized error responses.

### Field-level Validations

```python
def validate_phone_number(self, value):
    if not value:
        raise serializers.ValidationError("Phone number is required")
    if not value.isdigit():
        raise serializers.ValidationError(
            "Phone number must contain only digits"
        )
    if len(value) < 10 or len(value) > 15:
        raise serializers.ValidationError(
            "Phone number must be between 10 and 15 digits"
        )
    return value
```

### Overriding the `validate` Method

```python
def validate(self, data):
    # Check if email domain is allowed
    email = data.get("email")
    domain = email.split("@")[1]

    if domain in BLACKLISTED_DOMAINS:
        raise serializers.ValidationError("Email domain not allowed")

    # Check if username contains inappropriate words
    if any(
        word in data.get("username").lower() for word in INAPPROPRIATE_WORDS
    ):
        raise serializers.ValidationError(
            "Username contains inappropriate content"
        )

    return data
```

## Error Response Formats

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

This works well for most cases, but in structured projects where teams have their own internal style guides, you may need further customizations to conform to specified response formats.

For example, one project I worked on had a style guide requiring all validation error responses to follow this format:

```json
{
    "result": false,
    "message": "Error message"
}
```

## Challenges with Custom Validation Formats

`ValidationError` does accept dictionaries, so we might try:

```python
raise serializers.ValidationError(
    {
        "result": False,
        "message": "phone number is required",
    }
)
```

However, the output would look like:

```json
{
    "result": [
        "False"
    ],
    "message": [
        "phone number is required"
    ]
}
```

Notice that `ValidationError` has performed automatic list conversions and string coercion.

Interestingly, if you use `ValidationError` outside serializers, you get string transformations but not list conversions:

```json
{
    "result": "False",
    "message": "phone number is required"
}
```

This inconsistency is an unexpected quirk of the ValidationError implementation.

## Understanding Serializer Field Validation

DRF has a built-in validation pipeline that executes in this order:

1. Field-level validation (e.g., required fields, data types)
2. Object-level validation (via `.validate()` method)
3. Model validation when saving

When validation fails, DRF raises a `ValidationError`:

```python
class ValidationError(APIException):
    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = _("Invalid input.")
    default_code = "invalid"

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

The function `_get_error_details` handles the transformation:

```python
def _get_error_details(data, default_code=None):
    """
    Descend into a nested data structure, forcing any
    lazy translation strings or strings into `ErrorDetail`.
    """
    if isinstance(data, (list, tuple)):
        ret = [_get_error_details(item, default_code) for item in data]
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
    code = getattr(data, "code", default_code)
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

DRF's validation errors require error responses to be in the `ErrorDetail` format, which is a subclass of the `str` type. This leads to unexpected string transformations and list conversions.

## Solutions for Custom Error Formats

There are several ways to overcome this issue and conform to a custom style guide:

### Solution 1: Custom ValidationError Implementation

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

Usage:

```python
raise CustomValidationError(
    {
        "result": False,
        "message": "phone number is required",
    }
)
```

This approach overrides the default behaviors and allows us to specify our own response format.

### Solution 2: Custom Exception Handler

DRF [documentation](https://www.django-rest-framework.org/api-guide/exceptions/#custom-exception-handling) recommends using a custom exception handler if you need to follow a global uniform style guide:

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
                "success": False,
                "errors": errors,
                "message": "Validation failed",
            }

    return response
```

Register it in settings:

```python
REST_FRAMEWORK = {"EXCEPTION_HANDLER": "myapp.utils.custom_exception_handler"}
```

This approach also allows you to log errors to a file or cloud monitoring tools.

### Solution 3: Plain if/else Logic

You can bypass serializer validations entirely and implement your own validation logic:

```python
class SignupView(views.APIView):
    def post(self, request):
        data = request.data
        if len(data["password"]) < 8:
            return response.Response(
                {"password": "Password must be at least 8 characters"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not data["phone_number"].isdigit():
            return response.Response(
                {"phone_number": "Phone number must contain only digits"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # More validation...
        # Actually create user...
```

This approach is simpler and might be helpful when working with a team that has limited Django-DRF experience. However, it goes against Django's opinionated design patterns.

### Solution 4: The Pydantic Approach

If you're willing to deviate from DRF conventions, Pydantic offers powerful validation capabilities. However, this approach is mostly experimental, and at this stage, you might be better off adopting FastAPI if you prefer this style:

```python
from pydantic import BaseModel, validator, EmailStr


class UserSchema(BaseModel):
    email: EmailStr
    username: str
    password: str
    password_confirm: str

    @validator("password_confirm")
    def passwords_match(cls, v, values):
        if "password" in values and v != values["password"]:
            raise ValueError("Passwords don't match")
        return v

    @validator("email")
    def validate_email_domain(cls, v):
        domain = v.split("@")[1]
        if domain in BLACKLISTED_DOMAINS:
            raise ValueError("Email domain not allowed")
        return v
```

Using it with DRF:

```python
class SignupView(views.APIView):
    def post(self, request):
        data = request.data
        try:
            user_data = UserSchema(**data)
            # Continue with validated data
            return Response(
                UserSerializer(user).data, status=status.HTTP_201_CREATED
            )
        except ValidationError as e:
            return Response(
                {
                    "result": False,
                    "message": e.errors(),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
```

## Conclusion

Django REST Framework allows for rapid and robust development but has some limitations in terms of flexibility when adapting to specific project requirements.

I've outlined several approaches for implementing custom validations while still leveraging DRF's other advantages. I recommend using a custom exception handler for global specifications and custom ValidationError classes for specific cases. The if/else approach can work too, but be cautious of code complexity spiraling out of control.

Choose your approach based on your project's needs, your team's familiarity with Django, and how much you value consistency versus flexibility.

## References

- [Django REST Framework serializers](https://www.django-rest-framework.org/api-guide/serializers/)
- [Django REST Framework exceptions](https://www.django-rest-framework.org/api-guide/exceptions/#exceptions)
- [DRF ValidationError source code](https://github.com/encode/django-rest-framework/blob/73cbb9cd4acd36f859d9f656b8f134c9d2a754f3/rest_framework/exceptions.py#L143)
