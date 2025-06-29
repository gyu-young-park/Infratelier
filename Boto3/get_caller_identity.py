import boto3

sts = boto3.client("sts")
res = sts.get_caller_identity()

account = res["Account"]
arn = res["Arn"]
user_id = res["UserId"]

print(f"Account: {account}, ARN: {arn}, UserId: {user_id}")

if arn.endswith("root"):
    print("root 사용 중")
else:
    print("root 아님: " + arn)