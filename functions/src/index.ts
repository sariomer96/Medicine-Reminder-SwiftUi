import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { FirebaseMessagingError, getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

initializeApp();

type CareAlert = {
  caregiverId: string;
  patientId: string;
  patientName: string;
  medicationName: string;
  dosage: string;
  logId: string;
  scheduledTime: Timestamp;
  deliveredAt?: Timestamp | null;
  resolvedAt?: Timestamp | null;
};

type DeviceTokenRecord = {
  userId: string;
  deviceId: string;
  fcmToken: string;
  platform: string;
  updatedAt: Timestamp;
};

type MedicationLogRecord = {
  medicationId: string;
  userId: string;
  medicationName?: string | null;
  dosage?: string | null;
  scheduledTime: Timestamp;
  taken: boolean;
  takenAt?: Timestamp | null;
  updatedAt: Timestamp;
  alertStatus?: string | null;
};

type MedicationRecord = {
  userId: string;
  name: string;
  dosage: string;
  isDeleted?: boolean;
};

type RelationshipRecord = {
  caregiverId: string;
  patientId: string;
  status: string;
};

const db = getFirestore();
const messaging = getMessaging();
const iosBundleId = "sariomer.Medicine-Reminder";

type DebugPushRequest = {
  token: string;
  title?: string;
  body?: string;
  createdAt?: Timestamp;
};

export const sendDebugPushRequest = onDocumentCreated(
  {
    document: "debugPushRequests/{requestId}",
    region: "europe-west1"
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("debugPushRequests create event arrived without snapshot");
      return;
    }

    const request = snapshot.data() as DebugPushRequest;
    const token = request.token?.trim();

    if (!token) {
      await snapshot.ref.set(
        {
          status: "failed",
          error: "Missing token"
        },
        { merge: true }
      );
      return;
    }

    try {
      const messageId = await messaging.send({
        token,
        notification: {
          title: request.title?.trim() || "Medicine Reminder Test",
          body: request.body?.trim() || "Bu bir test bildirimidir."
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
            "apns-topic": iosBundleId
          },
          payload: {
            aps: {
              alert: {
                title: request.title?.trim() || "Medicine Reminder Test",
                body: request.body?.trim() || "Bu bir test bildirimidir."
              },
              sound: "default",
              badge: 1
            }
          }
        },
        data: {
          kind: "test-push"
        }
      });

      logger.info("Test push sent", { messageId, requestId: snapshot.id });
      await snapshot.ref.set(
        {
          status: "sent",
          messageId,
          deliveredAt: Timestamp.now()
        },
        { merge: true }
      );
    } catch (error) {
      logger.error("Test push failed", error);
      const resolvedError = error as Partial<FirebaseMessagingError> & {
        errorInfo?: {
          code?: string;
          message?: string;
        };
        code?: string;
        message?: string;
      };

      await snapshot.ref.set(
        {
          status: "failed",
          error: error instanceof Error ? error.message : String(error),
          errorCode: resolvedError.errorInfo?.code ?? resolvedError.code ?? null,
          errorMessage: resolvedError.errorInfo?.message ?? resolvedError.message ?? null,
          failedAt: Timestamp.now()
        },
        { merge: true }
      );
    }
  }
);

export const sendCareAlertNotification = onDocumentCreated(
  {
    document: "careAlerts/{alertId}",
    region: "europe-west1"
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("careAlerts create event arrived without snapshot");
      return;
    }

    const alert = snapshot.data() as CareAlert;
    if (!alert.caregiverId || alert.resolvedAt) {
      return;
    }

    const tokenSnapshot = await db
      .collection("deviceTokens")
      .where("userId", "==", alert.caregiverId)
      .get();

    const tokens = tokenSnapshot.docs
      .map((doc) => doc.data() as DeviceTokenRecord)
      .map((record) => record.fcmToken)
      .filter((token) => token.length > 0);

    if (tokens.length === 0) {
      logger.info("No device tokens found for caregiver", {
        caregiverId: alert.caregiverId,
        alertId: snapshot.id
      });
      return;
    }

    const dosageSuffix = alert.dosage.trim().length > 0 ? ` • ${alert.dosage}` : "";

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: `${alert.patientName} icin geciken ilac`,
        body: `${alert.medicationName}${dosageSuffix} dozu gecikti.`
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
          "apns-topic": iosBundleId
        },
        payload: {
          aps: {
            alert: {
              title: `${alert.patientName} icin geciken ilac`,
              body: `${alert.medicationName}${dosageSuffix} dozu gecikti.`
            },
            sound: "default",
            badge: 1
          }
        }
      },
      data: {
        careAlertId: snapshot.id,
        patientId: alert.patientId,
        logId: alert.logId
      }
    });

    const invalidTokens = response.responses
      .map((result, index) => ({ result, token: tokens[index] }))
      .filter(({ result }) => !result.success)
      .filter(({ result }) => {
        const code = result.error?.code ?? "";
        return code === "messaging/invalid-registration-token"
          || code === "messaging/registration-token-not-registered";
      })
      .map(({ token }) => token);

    if (invalidTokens.length > 0) {
      await deleteInvalidTokens(invalidTokens);
    }

    await snapshot.ref.set(
      {
        deliveredAt: Timestamp.now()
      },
      { merge: true }
    );

    logger.info("Care alert notification processed", {
      alertId: snapshot.id,
      successCount: response.successCount,
      failureCount: response.failureCount
    });
  }
);

export const processOverdueMedicationLogs = onSchedule(
  {
    schedule: "every 15 minutes",
    region: "europe-west1",
    timeZone: "Europe/Istanbul"
  },
  async () => {
    const now = new Date();
    const gracePeriodMs = 2 * 60 * 1000;
    const overdueThreshold = Timestamp.fromDate(new Date(now.getTime() - gracePeriodMs));

    const snapshot = await db.collection("medicationLogs")
      .where("taken", "==", false)
      .where("alertStatus", "==", "pending")
      .where("scheduledTime", "<=", overdueThreshold)
      .get();

    if (snapshot.empty) {
      logger.info("No overdue medication logs found");
      return;
    }

    for (const document of snapshot.docs) {
      const log = document.data() as MedicationLogRecord;
      logger.info("Evaluating overdue medication log", {
        logId: document.id,
        userId: log.userId,
        medicationId: log.medicationId,
        scheduledTime: log.scheduledTime.toDate().toISOString(),
        alertStatus: log.alertStatus ?? null
      });

      const medicationSnapshot = await db.collection("medications")
        .doc(log.medicationId)
        .get();

      const medication = medicationSnapshot.exists
        ? medicationSnapshot.data() as MedicationRecord
        : null;

      if (medicationSnapshot.exists && medication?.isDeleted) {
        logger.info("Medication is deleted, skipping overdue alert", {
          logId: document.id,
          medicationId: log.medicationId
        });
        await document.ref.set(
          {
            alertStatus: "deleted"
          },
          { merge: true }
        );
        continue;
      }

      if (!medicationSnapshot.exists) {
        logger.warn("Medication missing for overdue log, using denormalized log fields if available", {
          logId: document.id,
          medicationId: log.medicationId,
          hasMedicationName: Boolean(log.medicationName?.trim()),
          hasDosage: Boolean(log.dosage?.trim())
        });
      }

      const resolvedMedicationName = medication?.name ?? log.medicationName?.trim() ?? "";
      const resolvedDosage = medication?.dosage ?? log.dosage?.trim() ?? "";

      if (resolvedMedicationName.length === 0) {
        logger.warn("Skipping overdue log because medication details are unavailable", {
          logId: document.id,
          medicationId: log.medicationId
        });
        continue;
      }

      const userSnapshot = await db.collection("users")
        .doc(log.userId)
        .get();
      const patientName = userSnapshot.exists
        ? String(userSnapshot.data()?.name ?? "Yakininiz")
        : "Yakininiz";

      const relationshipsSnapshot = await db.collection("relationships")
        .where("patientId", "==", log.userId)
        .get();

      const caregivers = relationshipsSnapshot.docs
        .map((item) => item.data() as RelationshipRecord)
        .filter((relationship) => relationship.status === "accepted")
        .map((relationship) => relationship.caregiverId);

      logger.info("Resolved caregivers for overdue medication log", {
        logId: document.id,
        patientId: log.userId,
        caregiverCount: caregivers.length,
        caregiverIds: caregivers
      });

      if (caregivers.length === 0) {
        logger.warn("No accepted caregivers found for overdue medication log", {
          logId: document.id,
          patientId: log.userId
        });
        continue;
      }

      const batch = db.batch();

      for (const caregiverId of caregivers) {
        const alertRef = db.collection("careAlerts")
          .doc(`${caregiverId}_${document.id}`);

        logger.info("Creating care alert document", {
          logId: document.id,
          alertId: `${caregiverId}_${document.id}`,
          caregiverId
        });

        batch.set(alertRef, {
          caregiverId,
          patientId: log.userId,
          patientName,
          medicationName: resolvedMedicationName,
          dosage: resolvedDosage,
          logId: document.id,
          scheduledTime: log.scheduledTime,
          createdAt: Timestamp.now()
        }, { merge: true });
      }

      batch.set(document.ref, {
        alertStatus: "sent",
        alertCreatedAt: Timestamp.now()
      }, { merge: true });

      await batch.commit();

      logger.info("Committed overdue medication alert batch", {
        logId: document.id,
        medicationId: log.medicationId,
        createdAlertCount: caregivers.length
      });
    }

    logger.info("Processed overdue medication logs", {
      count: snapshot.size
    });
  }
);

export const resolveCareAlertsOnDoseTaken = onDocumentUpdated(
  {
    document: "medicationLogs/{logId}",
    region: "europe-west1"
  },
  async (event) => {
    const eventData = event.data;
    const before = eventData?.before.data() as MedicationLogRecord | undefined;
    const after = eventData?.after.data() as MedicationLogRecord | undefined;
    const logId = event.params.logId;

    if (!eventData || !before || !after) {
      return;
    }

    if (before.taken || !after.taken) {
      return;
    }

    const snapshot = await db.collection("careAlerts")
      .where("logId", "==", logId)
      .get();

    const batch = db.batch();

    for (const document of snapshot.docs) {
      batch.set(document.ref, {
        resolvedAt: Timestamp.now()
      }, { merge: true });
    }

    const afterRef = eventData.after.ref;

    batch.set(afterRef, {
      alertStatus: "resolved"
    }, { merge: true });

    await batch.commit();

    logger.info("Resolved care alerts after dose confirmation", {
      logId,
      alertsResolved: snapshot.size
    });
  }
);

async function deleteInvalidTokens(tokens: string[]): Promise<void> {
  for (const token of tokens) {
    const querySnapshot = await db
      .collection("deviceTokens")
      .where("fcmToken", "==", token)
      .get();

    for (const doc of querySnapshot.docs) {
      await doc.ref.delete();
    }
  }
}

// TODO:
// To support "patient app is fully closed" end-to-end, overdue dose creation
// must also move to the backend. Today this function sends push messages when a
// careAlerts document is created. The next step is generating those alerts from
// centralized medicationLogs data in Firestore.
