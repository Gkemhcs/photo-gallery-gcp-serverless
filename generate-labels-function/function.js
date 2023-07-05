const functions=require("@google-cloud/functions-framework")

async function request(auth,targetAudience,data) {
    url=targetAudience
    console.info(`request ${url} with target audience ${targetAudience}`);
    const client = await auth.getIdTokenClient(targetAudience);

    const res = await client.request({url,method:"POST",body: JSON.stringify(data),
    headers: {
      'Content-Type': 'application/json',
    }});
    console.info(res.data);
    console.log("function completed")
  }
functions.cloudEvent("generate-tags",async(cloudEvent)=>{
    const data=cloudEvent.data 
    const filename=data.name 
    const bucket=data.bucket
    gsutilurl=`gs://${bucket}/${filename}`
    const vision=require("@google-cloud/vision")
    const client=new vision.ImageAnnotatorClient()

    const [result] = await client.labelDetection(gsutilurl);
    const labelsgroup = result.labelAnnotations;
    labels=[]
 
    labelsgroup.forEach((element)=>{
labels.push(element.description.toLowerCase())
    })
    console.log("labels:-",labels)
    const {GoogleAuth} = require('google-auth-library');
    const auth = new GoogleAuth();
    targetAudience=process.env.targetAudience
    const resdata={imageurl:gsutilurl,labels:labels}
    request(auth,targetAudience,resdata)





})
