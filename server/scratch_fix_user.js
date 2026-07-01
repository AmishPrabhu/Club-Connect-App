import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

import User from './models/User.js';

async function run() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log("Connected to DB.");

    const email = 'santosh.amish@walchandsangli.ac.in';
    
    const result = await User.updateOne(
        { email },
        { 
            $set: { 
                clubId: "6986e133152807f4d001164b", 
                clubName: "Test" 
            } 
        }
    );
    console.log("Update result:", result);

    const user = await User.findOne({ email });
    console.log("Updated USER RECORD:\n", JSON.stringify(user, null, 2));

    await mongoose.disconnect();
}

run().catch(console.error);
