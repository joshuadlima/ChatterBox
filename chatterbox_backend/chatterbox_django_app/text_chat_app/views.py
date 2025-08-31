from django.shortcuts import render
from rest_framework.decorators import api_view
from rest_framework.response import Response

# Will not return a response until the user is matched or timeout of 120 seconds
@api_view(['GET'])
def match_view(request):
    
    return Response({"message": "Matched successfully."})
