#!/usr/bin/python3

"""
Class used for testing Azure ARM template-based deployment.

Objects require the following environment variables at instantiation:
    * AZURE_CLIENT_ID
    * AZURE_CLIENT_SECRET
    * AZURE_TENANT_ID
    * AZURE_SUBSCRIPTION_ID
"""

# standard imports
import json
import logging
import os
from datetime import datetime
from random import choice
from string import ascii_lowercase

# from requirements.txt
from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.resource.resources.models import DeploymentMode
from azure.mgmt.storage import StorageManagementClient
from azure.servicemanagement import ServiceManagementService


class ArmTemplateDeploy:
    def __init__(
        self,
        deploy_id=None,
        deploy_name="azurePySDK",
        deploy_params={},
        location="westus2",
        resource_group=None,
        storage_account=None,
        template={},
        _fields={},
    ):
        """Initialize, authenticate to Azure."""
        self.deploy_id = _fields.pop("deploy_id", deploy_id)
        self.deploy_name = _fields.pop("deploy_name", deploy_name)
        self.deploy_params = _fields.pop("deploy_params", deploy_params)
        self.location = _fields.pop("location", location)
        self.resource_group = _fields.pop("resource_group", resource_group)
        self.storage_account = _fields.pop("storage_account", storage_account)
        self.template = _fields.pop("template", template)

        if not self.deploy_id:
            self.deploy_id = (
                "av"
                + datetime.utcnow().strftime("%m%dx%H%M%S")
                + choice(ascii_lowercase)
            )

        if not self.resource_group:
            self.resource_group = self.deploy_id + "-rg"

        if not self.storage_account:
            self.storage_account = self.deploy_id + "sa"

        logging.debug("Loading Azure credentials")
        sp_creds = ServicePrincipalCredentials(
            client_id=os.environ["AZURE_CLIENT_ID"],
            secret=os.environ["AZURE_CLIENT_SECRET"],
            tenant=os.environ["AZURE_TENANT_ID"],
        )
        self.rm_client = ResourceManagementClient(
            credentials=sp_creds, subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"]
        )
        self.nm_client = NetworkManagementClient(
            credentials=sp_creds, subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"]
        )
        self.st_client = StorageManagementClient(
            credentials=sp_creds, subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"]
        )
        self.sm_client = ServiceManagementService(
            credentials=sp_creds, subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"]
        )

    def list_locations(self):
        result = self.sm_client.list_subscriptions()
        for location in result:
            print(location.name)
            location = location.name
            usage_list = self.st_client.usage()
            for location in usage_list:
                print()
                # TODO: the last for is wrong, need to get id of what is returned in usage
                # az vm list-usage --subscription <subID> --location eastus --output table | grep -e vCPUs -e Name
                # select random from list of results for location
                # return self.location = ("location", randomselectedlocation)

    def create_resource_group(self):
        """Creates the Azure resource group for this deployment."""
        logging.debug("Creating resource group: " + self.resource_group)
        return self.rm_client.resource_groups.create_or_update(
            self.resource_group, {"location": self.location}
        )

    def delete_resource_group(self):
        """Deletes the Azure resource group for this deployment."""
        logging.debug("Deleting resource group: " + self.resource_group)
        return self.rm_client.resource_groups.delete(self.resource_group)

    def deploy(self):
        """Deploys the Azure ARM template."""
        logging.debug("Deploying template")
        return self.rm_client.deployments.create_or_update(
            resource_group_name=self.resource_group,
            deployment_name=self.deploy_name,
            properties={
                "mode": DeploymentMode.incremental,
                "parameters": {k: {"value": v} for k, v in self.deploy_params.items()},
                "template": self.template,
            },
        )

    def serialize(self, store_template=False, to_file=None, *args, **kwargs):
        """
        Serialize this object into a JSON string. The Resource/Network/Storage
        Mgmt Client members are not serialized since deserialized instances
        should re-authenticate. Similarly, the deploy_params members can
        contain secrets (depending on the template), so it is not saved.

        If to_file is passed with a non-empty string value, the JSON string
        will be saved to a file whose name (including path) is to_file's value.

        This method returns the JSON string.
        """
        _this = self.__dict__
        _this.pop("rm_client", None)  # don't want to save these for security
        _this.pop("nm_client", None)
        _this.pop("st_client", None)
        _this.pop("deploy_params", None)

        if not store_template:
            _this.pop("template", None)

        if to_file:
            with open(to_file, "w") as tf:
                json.dump(_this, tf)

        return json.dumps(_this, *args, **kwargs)

    def __str__(self):
        return self.serialize(sort_keys=True, indent=4)


if __name__ == "__main__":
    pass
