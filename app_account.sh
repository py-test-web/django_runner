#!/bin/bash


# $1 == 1 => architecture_api: REST API(drf)
# $1 == 2 => architecture_api: GraphqL(graphene)

architecture_api=$1

#$2 : app_name_account
app_name_account=$2



./manage.py startapp "$app_name_account"

read -p "create user 1.mobile 2.email [2]" base_create_user
base_create_user=${base_create_user:-2}



if [ "$base_create_user" -eq 1 ]
then
auth_field="mobile = models.CharField(max_length=11, unique=True,validators=[MobileValidators()])"
field='mobile'
model_manager="
class UserManager(BaseUserManager):
    def create_user(self, mobile, username, password=None):
        if not mobile or not username:
            raise ValueError('Users must have an mobile and an username')

        user = self.model(mobile=mobile, username=username)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, mobile, username, password=None):
        user = self.create_user(mobile=mobile, username=username, password=password)
        user.is_admin = True
        user.save(using=self._db)
        return user"

model_validators='

class MobileValidators(RegexValidator):
    regex = r"^09\d{9}$"
    message = "phone number must be in format: 09*********"
    code = "invalid"
'
dependency_serializers_accuont='
from .models import MobileValidators
'
feild_serializers="mobile = serializers.CharField(validators=[MobileValidators()])"
elif [ "$base_create_user" -eq 2 ]
then
auth_field='email = models.EmailField(max_length=55, unique=True)'

field='email'
model_manager="
class UserManager(BaseUserManager):
    def create_user(self, email, username, password=None):
        if not email or not username:
            raise ValueError('Users must have an email address and an username')

        user = self.model(email=self.normalize_email(email), username=username)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, username, password=None):
        user = self.create_user(email=self.normalize_email(email), username=username, password=password)
        user.is_admin = True
        user.save(using=self._db)
        return user"

model_validators=""
dependency_serializers_accuont=''
feild_serializers="email = serializers.EmailField()"
fi


model_user="
class User(AbstractBaseUser):
    $auth_field
    username = models.CharField(unique=True, max_length=50)
    is_active = models.BooleanField(default=True)
    is_admin = models.BooleanField(default=False)

    objects = UserManager()

    USERNAME_FIELD='username'

    def __str__(self):
        return self.$field

    def has_perm(self, perm, obj=None):
        return True

    def has_module_perms(self, app_label):
        return True

    @property
    def is_staff(self):
        return self.is_admin"


cat >account/models.py <<EOF 
from django.db import models
from django.contrib.auth.models import BaseUserManager, AbstractBaseUser
from django.core.validators import RegexValidator

$model_manager
$model_validators
$model_user

class Opt(models.Model):
    code = models.PositiveSmallIntegerField()
    create_at = models.DateTimeField(auto_now=True)
    user = models.OneToOneField(User, on_delete=models.CASCADE)

EOF


cat >account/forms.py <<EOF 
from django import forms
from django.contrib.auth.forms import ReadOnlyPasswordHashField
from django.core.exceptions import ValidationError

from account.models import User


class UserCreationForm(forms.ModelForm):
    password1 = forms.CharField(label='Password', widget=forms.PasswordInput)
    password2 = forms.CharField(label='Password confirmation', widget=forms.PasswordInput)

    class Meta:
        model = User
        fields = ('$field', 'username')

    def clean_password2(self):
        password1 = self.cleaned_data.get("password1")
        password2 = self.cleaned_data.get("password2")
        if password1 and password2 and password1 != password2:
            raise ValidationError("Passwords don't match")
        return password2

    def save(self, commit=True):
        user = super().save(commit=False)
        user.set_password(self.cleaned_data["password1"])
        if commit:
            user.save()
        return user


class UserChangeForm(forms.ModelForm):
    password = ReadOnlyPasswordHashField()

    class Meta:
        model = User
        fields = ('$field', 'password', 'username', 'is_active', 'is_admin')
EOF



cat >account/admin.py <<EOF 
from django.contrib import admin
from django.contrib.auth.models import Group
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .forms import UserChangeForm, UserCreationForm
from .models import User


class UserAdmin(BaseUserAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    list_display = ('$field', 'username', 'is_admin')
    list_filter = ('is_admin',)
    fieldsets = (
        (None, {'fields': ('$field', 'username', 'password')}),
        ('Permissions', {'fields': ('is_admin',)}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('$field', 'username', 'password1', 'password2'),
        }),
    )
    search_fields = ('$field', 'username')
    ordering = ('$field',)
    filter_horizontal = ()


admin.site.register(User, UserAdmin)
admin.site.unregister(Group)
EOF


cat >account/util.py <<EOF
from random import randint
from django.conf import settings
import datetime
from .models import Opt, User
from django.db.models import Q


def get_user(user_id=None, $field=None, username=None):
    try:
        if user_id is not None:
            user = User.objects.get(id=user_id)
            return user
        if $field is not None:
            user = User.objects.get($field=$field)
            return user
        if username is not None:
            user = User.objects.get(username=username)
            return user
    except User.DoesNotExist:
        return None


def get_opt(user):
    try:
        opt = Opt.objects.get(user=user)
        return opt
    except Opt.DoesNotExist:
        return None


def check_time(opt):
    result = opt.create_at + datetime.timedelta(seconds=settings.TIME_REGISTER_VERIFY_CODE)
    if result.timestamp() > datetime.datetime.now().timestamp():
        return True


def send_verify_code($field):
    user = get_user($field=$field)
    if user is not None:
        code = randint(1120, 9980)
        opt = get_opt(user)
        if opt is not None:
            if check_time(opt):
                return None
            opt.delete()
        Opt.objects.create(code=code, user=user)
        # TODO function send(email or mobile)
        return True


def check_verify_code($field, code):
    user = get_user($field=$field)
    opt = get_opt(user=user)

    if user is not None and opt is not None:
        if check_time(opt):
            print("time ok")
            if opt.code == code:
                print("code ok")
                user.is_active = True
                user.save()
                opt.delete()
                return True
        else:
            opt.delete()
            if not user.is_active:
                user.delete()


def final_create_user($field, username, password):
    user = User.objects.create_user($field=$field, username=username, password=password)
    send_verify_code($field)
    return user


def create_user($field, username, password):
    user = User.objects.filter(Q($field=$field) | Q(username=username))
    if not user.exists():
        return final_create_user($field, username, password)
    else:
        print(user)
        if not user.first().is_active:
            opt = Opt.objects.filter(user=user.first())
            if not opt.exists():
                user.delete()
                return final_create_user($field, username, password)
            else:
                if not check_time(opt[0]):
                    user.delete()
                    opt.first().delete()
                    return final_create_user($field, username, password)


def set_new_password(code, $field, new_password):
    if check_verify_code($field, code):
        user = get_user($field=$field)
        user.set_password(new_password)
        user.save()
        return True

EOF


if [ "$architecture_api" -eq 1 ]
then
cat >account/serializers.py <<EOF 
from rest_framework import serializers
from .models import User
$dependency_serializers_accuont


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('$field', 'password', 'username', 'is_active', 'is_admin')
        extra_kwargs = {
            'password': {
                'write_only': True
            }
        }


class CreateUserSerializer(serializers.Serializer):
    $feild_serializers
    password = serializers.CharField(write_only=True)
    username = serializers.CharField()


class VerifyUserSerializer(serializers.Serializer):
    $feild_serializers
    code = serializers.IntegerField()


class ResetPasswordSerializer(serializers.Serializer):
    $feild_serializers


class ResetPasswordConfirmSerializer(serializers.Serializer):
    $feild_serializers
    code = serializers.IntegerField()
    new_password = serializers.CharField()

EOF

cat >account/api_views.py <<EOF 
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from .serializers import (CreateUserSerializer, VerifyUserSerializer, UserSerializer,
                          ResetPasswordSerializer, ResetPasswordConfirmSerializer)
from .util import (create_user, check_verify_code, get_user,
                   send_verify_code, set_new_password)


class UserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = get_user(user_id=request.query_params.get("id"))
        if user is not None:
            obj = UserSerializer(instance=user)
            return Response(data=obj.data)
        return Response({'ok': False})


class CreateUserView(APIView):
    def post(self, request):
        print('CreateUserView')
        info = CreateUserSerializer(data=request.data)
        if info.is_valid():
            $field = info.validated_data['$field']
            username = info.validated_data['username']
            password = info.validated_data['password']
            user = create_user($field, username, password)
            if user is not None:
                obj_ser = CreateUserSerializer(instance=user)
                return Response(data=obj_ser.data)
        return Response({'ok': False})


class VerifyUser(APIView):
    def post(self, request):
        info = VerifyUserSerializer(data=request.data)
        if info.is_valid():
            $field = info.validated_data['$field']
            code = info.validated_data['code']
            if check_verify_code($field, code):
                return Response({'ok': True})
        return Response({'ok': False})


class ResetPassword(APIView):
    def post(self, request):
        info = ResetPasswordSerializer(data=request.data)
        if info.is_valid():
            $field = info.validated_data['$field']
            if send_verify_code($field):
                return Response({'ok': True})
        return Response({'ok': False})


class RestPasswordConfirm(APIView):
    def post(self, request):
        info = ResetPasswordConfirmSerializer(data=request.data)
        if info.is_valid():
            $field = info.validated_data['$field']
            code = info.validated_data['code']
            new_password = info.validated_data['new_password']
            if set_new_password(code, $field, new_password):
                return Response({'ok': True})
        return Response({'ok': False})

EOF

cat >account/urls.py <<EOF 
from django.urls import path
from account.api_views import UserView, CreateUserView, VerifyUser, ResetPassword, RestPasswordConfirm
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

app_name = 'account'

urlpatterns = [
    path('', UserView.as_view()),
    path('create/', CreateUserView.as_view()),
    path('verify/', VerifyUser.as_view()),
    path('reset/', ResetPassword.as_view()),
    path('reset/confirm/', RestPasswordConfirm.as_view()),
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]
EOF
dependency_urls_core=""
path_urls_core="path('api/account/', include('account.urls', namespace='account')),"

elif [ "$architecture_api" -eq 2 ]
then
cat >account/schema.py <<EOF
from graphene_django.types import DjangoObjectType
import graphene
import graphql_jwt
from graphql_jwt.decorators import login_required

from .models import User
from .util import check_verify_code, create_user, send_verify_code, set_new_password


class UserType(DjangoObjectType):
    class Meta:
        model = User
        fields = ('$field', 'username', 'is_active', 'is_admin')


class UserQuery(graphene.ObjectType):
    user = graphene.Field(UserType)

    @login_required
    def resolve_user(self, info):
        return info.context.user


class CreateUser(graphene.Mutation):
    ok = graphene.Boolean(default_value=False)

    class Arguments:
        $field = graphene.String(required=True)
        username = graphene.String(required=True)
        password = graphene.String(required=True)

    @staticmethod
    def mutate(cls, info, $field, username, password):
        user = create_user($field, username, password)
        return CreateUser() if user is None else CreateUser(ok=True)


class VerifyUser(graphene.Mutation):
    ok = graphene.Boolean(default_value=False)

    class Arguments:
        code = graphene.Int(required=True)
        $field = graphene.String(required=False)

    @staticmethod
    def mutate(cls, info, code, $field):
        is_check = check_verify_code($field, code)
        return VerifyUser(ok=True) if is_check else VerifyUser()


class ResetPassword(graphene.Mutation):
    ok = graphene.Boolean(default_value=False)

    class Arguments:
        $field = graphene.String(required=True)

    @staticmethod
    def mutate(cls, info, $field):
        is_send = send_verify_code($field)
        return CreateUser(ok=True) if is_send else CreateUser()


class ResetConfirmPassword(graphene.Mutation):
    ok = graphene.Boolean(default_value=False)

    class Arguments:
        code = graphene.Int(required=True)
        $field = graphene.String(required=True)
        new_password = graphene.String(required=True)

    @staticmethod
    def mutate(cls, info, code, $field, new_password):
        is_set = set_new_password(code, $field, new_password)
        return ResetConfirmPassword(ok=True) if is_set else ResetConfirmPassword()


class UserMutation(graphene.ObjectType):
    verify_user = VerifyUser.Field()
    create_user = CreateUser.Field()
    reset_password = ResetPassword.Field()
    reset_confirm_password = ResetConfirmPassword.Field()
    token_auth = graphql_jwt.ObtainJSONWebToken.Field()
    verify_token = graphql_jwt.Verify.Field()
    refresh_token = graphql_jwt.Refresh.Field()

EOF

cat >core/schema.py <<EOF
import graphene
from account.schema import UserQuery, UserMutation


class Query(UserQuery, graphene.ObjectType):
    pass


class Mutation(UserMutation, graphene.ObjectType):
    pass


my_schema = graphene.Schema(query=Query, mutation=Mutation)

EOF

dependency_urls_core="

from django.views.decorators.csrf import csrf_exempt
from graphene_django.views import GraphQLView
"
path_urls_core="path('api/', csrf_exempt(GraphQLView.as_view(graphiql=False)))"

fi

cat >core/urls.py <<EOF
from django.contrib import admin
from django.urls import path, include
$dependency_urls_core


urlpatterns = [
    path('admin/', admin.site.urls),
    $path_urls_core
]

EOF