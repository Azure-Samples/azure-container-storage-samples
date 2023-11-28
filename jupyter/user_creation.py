import requests
from time import sleep

# Set the base URL for the JupyterHub REST API
base_url = "http://localhost:8080/hub/api"

# Set your API token
api_token = ""

# Define an array of usernames
usernames = []
for x in range (50):
    temp_user = f"user{x}"
    usernames.append(temp_user)

    # Set the URL for creating a new user
url = f"{base_url}/users"   

# Set the headers to include the API token
headers = {
    "Authorization": f"token {api_token}"
}
body={
    "usernames": usernames,
    "admin": True
}

# Send a POST request to batch create all the new users
response = requests.post(url, headers=headers,json=body)
# Check if the request was successful
if response.status_code == 201:
    print(f"Created user: {usernames}")
else:
    print(f"Failed to create user: {response}")

# For each user POST request to create Jupyter Notebook session
for user in usernames:
    server_url = f"{base_url}/users/{user}/server"
    response = requests.post(server_url, headers=headers,json={})

    if response.status_code == 201 or response.status_code == 202:
        print(f"Started {user} server")
    else:
        print(f"Failed to start {user} server: {response.json} {response.status_code}")
    sleep(0.5)