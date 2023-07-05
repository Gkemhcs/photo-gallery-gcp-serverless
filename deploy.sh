#! /bin/bash 
echo "WE ARE ABOUT TO START TO DEPLOY THE PHOTO WEB APP GALLERY  🤌"
echo "ENTER YOUR PROJECT ID"
read PROJECT_ID
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format "value(projectNumber)")
gcloud config set project $PROJECT_ID
echo "ENABLING THE REQUIRED APIS"
gcloud services enable eventarc.googleapis.com cloudfunctions.googleapis.com \
run.googleapis.com pubsub.googleapis.com firestore.googleapis.com  artifactregistry.googleapis.com  cloudbuild.googleapis.com vision.googleapis.com
echo "CREATING THE FIRESTORE DATABASE"
gcloud beta firestore databases create --location eur3 --type firestore-native
echo "CREATING THE REQUIRED SERVICE ACCOUNTS"
# creating sa 
gcloud iam service-accounts create run-sa --display-name cloud-run-app 
gcloud iam service-accounts  create eventarc-sa --display-name eventarc-sa 
gcloud iam service-accounts create label-generator-function --display-name label-gen-func-sa 
gcloud iam service-accounts create firestore-generator-function --display-name label-gen-func-sa
echo "CREATING THE ARTIFACT REPOSITORY TO STORE THE DOCKER ARTIFACTS"
gcloud artifacts repositories create repo-gallery --repository-format docker \
 --location us-central1 --labels=app=photo-gallery --description "docker registry to store photo gallery web app artifacts"
# creating the cloud storage bucket to store the uploaded photos 
echo "ENTER THE NAME SUFFIX OF CLOUD STORAGE BUCKET"
read BUCKET_NAME_SUFFIX 
BUCKET_NAME="${PROJECT_ID}-${BUCKET_NAME_SUFFIX}"
gsutil mb -l us-central1 gs://$BUCKET_NAME
echo "ALLOWING THE PUBLIC READ ACCESS TO BUCKET "
gsutil  iam ch allUsers:objectViewer gs://$BUCKET_NAME
gsutil iam ch serviceAccount:run-sa@$PROJECT_ID.iam.gserviceaccount.com:objectCreator  gs://$BUCKET_NAME
echo "assigning the required iam roles to service accounts"
CLOUD_STORAGE_SA=$(gsutil kms serviceaccount -p ${PROJECT_ID})
gcloud projects add-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:${CLOUD_STORAGE_SA}" \
--role roles/pubsub.publisher

gcloud projects add-iam-policy-binding $PROJECT_ID   \
   --member "serviceAccount:run-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
   --role roles/datastore.user 

gcloud projects add-iam-policy-binding $PROJECT_ID  \
  --member "serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role roles/iam.serviceAccountTokenCreator
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:eventarc-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/eventarc.eventReceiver
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:eventarc-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/run.invoker
gcloud projects add-iam-policy-binding $PROJECT_ID \
   --member "serviceAccount:label-generator-function@${PROJECT_ID}.iam.gserviceaccount.com" \
   --role roles/storage.admin 
gcloud projects add-iam-policy-binding  $PROJECT_ID \
   --member "serviceAccount:firestore-generator-function@${PROJECT_ID}.iam.gserviceaccount.com" \
   --role roles/datastore.user
cd app 
gcloud builds submit -t us-central1-docker.pkg.dev/$PROJECT_ID/repo-gallery/photo-web-app  --ignore-file .gitignore  . 
gcloud run deploy photo-web-app --region us-central1 \
--image us-central1-docker.pkg.dev/$PROJECT_ID/repo-gallery/photo-web-app \
--allow-unauthenticated \
--set-env-vars=PROJECT_ID=$PROJECT_ID,BUCKET_NAME=$BUCKET_NAME \
--service-account "run-sa@${PROJECT_ID}.iam.gserviceaccount.com"
cd ../firestore-ingestor-function/
gcloud functions deploy firestore-ingester --entry-point firestore-ingester \
--gen2 \
--runtime nodejs16 \
--trigger-http \
--no-allow-unauthenticated  \
--source . \
--trigger-service-account "eventarc-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--max-instances 3 \
--region us-central1 \
--service-account "firestore-generator-function@${PROJECT_ID}.iam.gserviceaccount.com"
FUNCTION_URL=$(gcloud functions describe firestore-ingester --region us-central1 --format "value(url)" )
cd ../generate-labels-function
gcloud functions deploy labels-ingestor --runtime nodejs16 \
--entry-point generate-tags \
--gen2  \
--trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
--trigger-event-filters="bucket=${BUCKET_NAME}" \
--trigger-service-account "eventarc-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--service-account  "label-generator-function@${PROJECT_ID}.iam.gserviceaccount.com" \
--max-instances 3 \
--region us-central1 \
--source . \
--set-env-vars=targetAudience=$FUNCTION_URL
gcloud functions add-invoker-policy-binding firestore-ingester --region us-central1 --member "serviceAccount:label-generator-function@${PROJECT_ID}.iam.gserviceaccount.com"





