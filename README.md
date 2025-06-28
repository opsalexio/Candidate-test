Create a virtual machine (VM) in Azure on which a minimal container environment is set up. On it, deploy a
Keycloak container and an attached Postgres database, as well as a web server with a static web page whose
access is controlled by the Keycloak.

Implementation:  
- The project is to be implemented on GitHub.  
• Creation according to the Git workflow  
• Creation of minimal but meaningful documentation (with architecture)  
- Creation of all infrastructure components is to be done using Terraform.  
• Creation of necessary managed identities/service principals is not part of the task.  

- Justify your choice:  
▪ of the components used  
• Why were the components created?  
• Why did you not use other components?  
▪ the images used  
▪ the network configuration  

- All infrastructure configurational work should be done using Ansible wherever possible.  
- Justify the choice of the container environment.  
- Create GitHub Actions that will:  
• roll out  
• configure  
• and disassemble the project.   
- Name possible features that extend the project and describe the benefits of the features added.  
