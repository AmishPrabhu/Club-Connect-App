// Firebase Admin SDK initialization config wrapper
import { initializeApp, cert } from 'firebase-admin/app';
import fs from 'fs';
import path from 'path';

let firebaseApp = null;

try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        firebaseApp = initializeApp({
            credential: cert(serviceAccount)
        });
        console.log("Firebase Admin SDK initialized successfully from environment JSON.");
    } else if (process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
        const resolvedPath = path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
        const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
        firebaseApp = initializeApp({
            credential: cert(serviceAccount)
        });
        console.log("Firebase Admin SDK initialized successfully from file path.");
    } else {
        console.warn("Neither FIREBASE_SERVICE_ACCOUNT_JSON nor FIREBASE_SERVICE_ACCOUNT_PATH is set. Push notifications will be disabled.");
    }
} catch (error) {
    console.error("Failed to initialize Firebase Admin SDK:", error);
}

export default firebaseApp;
