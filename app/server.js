const express=require("express")
const app=express()
const ejs=require("ejs")
const multer=require("multer")
const bodyParser=require("body-parser")
const {Storage}=require("@google-cloud/storage")
const storage=new Storage({projectId:process.env.PROJECT_ID})
const bucket=storage.bucket(process.env.BUCKET_NAME)
app.set("view engine","ejs")
app.use(bodyParser.urlencoded({extended:true}))
app.use(express.static("public"))
const upload=multer({storage:multer.memoryStorage()})
const Firestore=require("@google-cloud/firestore")
const db=new Firestore({projectId:process.env.PROJECT_ID})
app.get("/",(req,res)=>{
    res.render("upload")
})
app.post("/upload",upload.single('file'),(req,res)=>{
 file=req.file
 console.log(file)
 filename=file.originalname
 console.log(filename)
 destfile=req.body.name 
 date=new Date().getTime()
 extension=file.originalname.split(".").pop()
 console.log("extension",extension)
 destfilename="posts/"+destfile+date+"."+extension
 
 const uploadfile=bucket.file(destfilename)
 const stream=uploadfile.createWriteStream({metadata:{contentType:file.mimeType}})
 stream.on('finish',(err)=>{
    if(err) throw err 
    else{
        console.log("upload  success")
    }
 })
 stream.on('error', (err) => {
    console.error('Error uploading file to Google Cloud Storage:', err);
    res.status(500).send('Error uploading file');
  });
 stream.end(file.buffer);
res.redirect("/success")
})
app.get("/success",(req,res)=>{
    res.render("success-response")
})
async function getimages(db,tag){
const results=await db.collection("images").where("labels","array-contains",tag.toLowerCase()).get()

imageurls=[]
results.forEach((image)=>{
    data=image.data()
    imageurls.push(data.imageurl)
  
})
return imageurls
}
app.post("/gallery",async (req,res)=>{
    tag=req.body.tag
   const imageurls= await getimages(db,tag) 
 latest_img_urls=[]
   console.log(imageurls)
   imageurls.forEach((element)=>{
  latest_img_urls.push(element.replace("gs://","https://storage.googleapis.com/"))
   })
   console.log( latest_img_urls)
   res.render("gallery",{imageurls: latest_img_urls})

})


app.listen(8080,()=>{
    console.log("server started")
})