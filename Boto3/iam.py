import boto3

iam = boto3.client("iam")

roles = iam.list_roles()["Roles"]
for role in roles:
    # 검사하면 안되는 role
    if role["Path"].startswith((
            "/aws-reserved/",
            "/service-role/",
            "/aws-service-role/",
        )
    ):
        continue

    role_name = role["RoleName"]
    
    try:
        # role에 대해서 자세한 내용 확인
        res = iam.get_role(RoleName=role_name)["Role"]
        # 사용 한 적이 없다면 빈 값이 나온다. 또는 400일 간 사용한 적이 없는 경우 
        if not res["RoleLastUsed"]:
            print(res["Arn"], res["RoleLastUsed"])
    except iam.exceptions.NoSuchEntityException:
        print(f"[X] {role_name} ")
    