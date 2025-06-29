import boto3

ec2 = boto3.client("ec2")

vpcs = ec2.describe_vpcs(
    Filters=[
        {
            "Name": "tag:Name",
            "Values": [
                "main-vpc"
            ]
        }
    ]
)["Vpcs"]

if not vpcs:
    res = ec2.create_vpc(
        CidrBlock="10.0.0.0/16",
        TagSpecifications=[
            {
                "ResourceType": "vpc",
                "Tags": [
                    {
                        "Key": "Name",
                        "Value": "main-vpc",
                    }
                ]
            }
        ]
    )
    print(res)
else:
    res = ec2.delete_vpc(VpcId=vpcs[0]["VpcId"])
    print(res)