// Firebase Admin SDK initialization config wrapper
import { initializeApp, cert } from 'firebase-admin/app';
import fs from 'fs';
import path from 'path';

let firebaseApp = null;

if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    try {
        const resolvedPath = path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
        const serviceAccount = JSON.parse(
            fs.readFileSync(resolvedPath, 'utf8')
        );
        firebaseApp = initializeApp({
            credential: cert(serviceAccount)
        });
        console.log("Firebase Admin SDK initialized successfully.");
    } catch (error) {
        console.error("Failed to initialize Firebase Admin SDK:", error);
    }
} else {
    console.warn("FIREBASE_SERVICE_ACCOUNT_PATH is not set in the environment. Push notifications will be disabled.");
}

export default firebaseApp;
