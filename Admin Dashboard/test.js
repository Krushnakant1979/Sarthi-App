import { initializeApp } from "firebase/app";
import { getFirestore, doc, updateDoc } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyCZgfdYu_DVHm3Ai5jNukAaZCtqp2wGKpk",
  authDomain: "rapido-app-8745a.firebaseapp.com",
  projectId: "rapido-app-8745a"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function run() {
  const capId = "ieLL5ENvcRQV1BR7RHbs07BC4GF3";
  await updateDoc(doc(db, "users", capId), {
    isOnline: false
  });
  console.log("Captain set to offline successfully.");
  process.exit(0);
}

run();
