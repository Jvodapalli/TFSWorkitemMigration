# TFSWorkitemMigration
This script is used to migrate WI from TFS On Premise to VSTS and Vice-versa with Attachments.

TFS Workitem Migration script is powershell scripts which uses TFS/Vsts apis to migrate work items based on query created.
same script can be used for migrating from
- TFS on-premise one project to other 
- VSTS one project to other
- TFS to vsts,vise-versa

##Prerequisite:
- create query for which you need to migrate in destination.
- personalization token ( if you want to migrate it to VSTS)
- Need a attjson.txt file in physical locaiton 
- Need CSV file for exporting migrated list.

##Actions:
As apart of migration this script can take care of below actions:
- Fields
- creating New Workitem
- Updating each fields
- Attachments
- Linking Child and parent WI 
- History ( but only latest one can be possible)

##Description of how the script works:
lets take if you are migrating EPIC workitem which has 2 feature child WI and in which feature has 4 child, 2 PBI and 2 bugs. You need to write a query in which it has Epic WI, based on WI listed using query ,it perform migrating all workitems which are listed as a part of query result. based on query result it will check what type of WI it is and it will create new WI and checks if it has child work item and it wil takecare of child and innerchild workitems aswell
if you are migrating Epic workflow is
- create epic
- check for child(feature) if not create and link to parent(based on relation) and also update fields based on source
- check child(feature) has a inner child(PBI and BUg) and link it and also updatred the fields based on source.

##Note:
- While migrating custom fields from source to destination make sure custom fields which exist in source are need to be created in destination.If not update the if loops in script.



