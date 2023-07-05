const functions=require("@google-cloud/functions-framework")

async function addData(data,db){
  
    await db.collection("images").add(data)
    console.log("successfully ingested data into firestore")
}

functions.http("firestore-ingester",(req,res)=>{

   console.log(req.body)
    console.log(typeof req.body)
     data=req.body
    const Firestore=require("@google-cloud/firestore")
    const db=new Firestore()
    addData(data,db)
    console.log("successfully inserted data  into firestore")
    res.send("ok")
})  
