# n8n-linkedin-automated-post
Contains docker compose file and n8n workflow for automated post on linkedin

Prereqs
1. docker and docker compose should be installed
2. docker should be up and running

Deployment
1. Modify docker-compose.yml and add host ip in given placeholder <hostio>
2. Run pre-setup.sh script to create required folder structure
3. Start docker compose using `docker compose up -d`
4. Once all the containers are up then run post-setup.sh to download required modules.
5. Access n8n from browser.
6. import the workflow.json
7. create requird credentials.
8. Execute the workflow to see the magic.
