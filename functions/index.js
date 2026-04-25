// /**
// * Import function triggers from their respective submodules:
// *
// * const {onCall} = require("firebase-functions/v2/https");
// * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
// *
// * See a full list of supported triggers at https://firebase.google.com/docs/functions
// */
//
// const {setGlobalOptions} = require("firebase-functions");
// const {onRequest} = require("firebase-functions/https");
// const logger = require("firebase-functions/logger");
//
// // For cost control, you can set the maximum number of containers that can be
// // running at the same time. This helps mitigate the impact of unexpected
// // traffic spikes by instead downgrading performance. This limit is a
// // per-function limit. You can override the limit for each function using the
// // `maxInstances` option in the function's options, e.g.
// // `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// // NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// // functions should each use functions.runWith({ maxInstances: 10 }) instead.
// // In the v1 API, each function can only serve one request per container, so
// // this will be the maximum concurrent request count.
// setGlobalOptions({ maxInstances: 10 });
//
// // Create and deploy your first functions
// // https://firebase.google.com/docs/functions/get-started
//
// // exports.helloWorld = onRequest((request, response) => {
// //   logger.info("Hello logs!", {structuredData: true});
// //   response.send("Hello from Firebase!");
// // });
//

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const cors = require("cors")({origin: true});

admin.initializeApp();

const db = admin.firestore();

// eslint-disable-next-line require-jsdoc
async function getAdminUser(req) {
  const authHeader = req.headers.authorization || "";
  const match = authHeader.match(/^Bearer (.+)$/);

  if (!match) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Missing authorization token.",
    );
  }

  const decodedToken = await admin.auth().verifyIdToken(match[1]);
  const adminDoc = await db.collection("users").doc(decodedToken.uid).get();

  if (!adminDoc.exists || adminDoc.data().role !== "admin") {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Admin privileges are required.",
    );
  }

  return decodedToken;
}

// eslint-disable-next-line require-jsdoc
function sendHttpError(res, error) {
  const code = error.code === "permission-denied" ? 403 :
    error.code === "unauthenticated" ? 401 : 400;

  res.status(code).json({
    error: error.message || "Request failed.",
  });
}

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "YOUR_EMAIL@gmail.com",
    pass: "APP_PASSWORD",
  },
});

const otpStore = {};

exports.sendOtp = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const email = req.body.email;

    const otp = Math.floor(100000 + Math.random() * 900000);

    otpStore[email] = otp;

    await transporter.sendMail({
      from: "Bank App",
      to: email,
      subject: "Your OTP Code",
      text: `Your verification code is: ${otp}`,
    });

    res.status(200).send("OTP sent");
  });
});

exports.verifyOtp = functions.https.onRequest((req, res) => {
  cors(req, res, () => {
    const email = req.body.email;
    const code = req.body.code;

    if (otpStore[email] == code) {
      delete otpStore[email];

      res.status(200).send("verified");
    } else {
      res.status(401).send("wrong code");
    }
  });
});

exports.adminUpdateUser = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed"});
      return;
    }

    try {
      await getAdminUser(req);

      const {uid, name, email, password, role} = req.body;

      if (!uid) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "User uid is required.",
        );
      }

      const authUpdates = {};
      const profileUpdates = {};

      if (typeof email === "string" && email.trim().length > 0) {
        authUpdates.email = email.trim();
        profileUpdates.email = email.trim();
      }

      if (typeof password === "string" && password.trim().length > 0) {
        if (password.trim().length < 6) {
          throw new functions.https.HttpsError(
              "invalid-argument",
              "Password must be at least 6 characters.",
          );
        }

        authUpdates.password = password.trim();
      }

      if (typeof name === "string" && name.trim().length > 0) {
        profileUpdates.name = name.trim();
      }

      if (role === "admin" || role === "user") {
        profileUpdates.role = role;
      }

      if (Object.keys(authUpdates).length > 0) {
        await admin.auth().updateUser(uid, authUpdates);
      }

      if (Object.keys(profileUpdates).length > 0) {
        await db
            .collection("users")
            .doc(uid)
            .set(profileUpdates, {merge: true});
      }

      res.status(200).json({success: true});
    } catch (error) {
      sendHttpError(res, error);
    }
  });
});

exports.adminDeleteUser = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed"});
      return;
    }

    try {
      const adminUser = await getAdminUser(req);
      const {uid} = req.body;

      if (!uid) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "User uid is required.",
        );
      }

      if (uid === adminUser.uid) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Admins cannot delete their own account.",
        );
      }

      const transactions = await db.collection("transactions")
          .where("userId", "==", uid)
          .get();

      const batch = db.batch();
      transactions.docs.forEach((doc) => batch.delete(doc.ref));
      batch.delete(db.collection("users").doc(uid));
      await batch.commit();

      await admin.auth().deleteUser(uid);

      res.status(200).json({success: true});
    } catch (error) {
      sendHttpError(res, error);
    }
  });
});
