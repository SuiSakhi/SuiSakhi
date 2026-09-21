'use strict';

const crypto = require('node:crypto');

const DEFAULT_LEASE_MS = 15 * 60 * 1000;

function validDate(value, code) {
  const date =
    value instanceof Date
      ? value
      : new Date(value);

  if (Number.isNaN(date.getTime())) {
    throw new Error(
      `${code}: A valid date is required.`,
    );
  }

  return date;
}

function positiveInteger(value, fallback) {
  return Number.isInteger(value) && value > 0
    ? value
    : fallback;
}

function storedDate(value) {
  if (value instanceof Date) {
    return value;
  }

  if (
    value &&
    typeof value.toDate === 'function'
  ) {
    return value.toDate();
  }

  const parsed = new Date(value);

  return Number.isNaN(parsed.getTime())
    ? null
    : parsed;
}

function createProcessingRunStore({
  db,
  now = () => new Date(),
  leaseMs = DEFAULT_LEASE_MS,
  tokenFactory = () => crypto.randomUUID(),
}) {
  if (
    !db ||
    typeof db.doc !== 'function' ||
    typeof db.runTransaction !== 'function'
  ) {
    throw new Error(
      'RUN_STORE_DB_INVALID: Firestore is required.',
    );
  }

  const normalizedLeaseMs =
    positiveInteger(
      leaseMs,
      DEFAULT_LEASE_MS,
    );

  async function claim(identity) {
    if (
      !identity ||
      !identity.firestorePath ||
      !identity.runId
    ) {
      throw new Error(
        'RUN_IDENTITY_INVALID: Event identity is required.',
      );
    }

    const claimToken = tokenFactory();

    if (
      typeof claimToken !== 'string' ||
      claimToken.trim().length === 0
    ) {
      throw new Error(
        'RUN_CLAIM_TOKEN_INVALID: Claim token is required.',
      );
    }

    const ref =
      db.doc(identity.firestorePath);

    return db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(ref);

        const claimedAt =
          validDate(
            now(),
            'RUN_CLAIM_DATE_INVALID',
          );

        const leaseExpiresAt =
          new Date(
            claimedAt.getTime() +
            normalizedLeaseMs,
          );

        if (!snapshot.exists) {
          transaction.create(ref, {
            runId: identity.runId,
            bucket: identity.bucket,
            objectPath:
              identity.objectPath,
            generation:
              identity.generation,
            profileCode:
              identity.profileCode,
            processingVersion:
              identity.processingVersion,
            status: 'processing',
            attemptCount: 1,
            claimToken:
              claimToken.trim(),
            claimedAt,
            leaseExpiresAt,
            createdAt: claimedAt,
            updatedAt: claimedAt,
            completedAt: null,
            processorRunId: null,
            manifestPath: null,
            failureCode: null,
            failureMessage: null,
            failedAt: null,
          });

          return {
            acquired: true,
            reason: 'NEW_RUN',
            attemptCount: 1,
            claimToken:
              claimToken.trim(),
            claimedAt,
            leaseExpiresAt,
          };
        }

        const data =
          snapshot.data() || {};

        if (data.status === 'completed') {
          return {
            acquired: false,
            reason:
              'ALREADY_COMPLETED',
            attemptCount:
              positiveInteger(
                data.attemptCount,
                1,
              ),
            claimToken: null,
          };
        }

        const currentLease =
          storedDate(
            data.leaseExpiresAt,
          );

        if (
          data.status === 'processing' &&
          currentLease &&
          currentLease.getTime() >
            claimedAt.getTime()
        ) {
          return {
            acquired: false,
            reason:
              'ALREADY_PROCESSING',
            attemptCount:
              positiveInteger(
                data.attemptCount,
                1,
              ),
            claimToken: null,
          };
        }

        const attemptCount =
          positiveInteger(
            data.attemptCount,
            0,
          ) + 1;

        const reason =
          data.status === 'failed'
            ? 'RETRY_FAILED_RUN'
            : 'RETRY_EXPIRED_LEASE';

        transaction.set(
          ref,
          {
            status: 'processing',
            attemptCount,
            claimToken:
              claimToken.trim(),
            claimedAt,
            leaseExpiresAt,
            updatedAt: claimedAt,
            completedAt: null,
            processorRunId: null,
            manifestPath: null,
            failureCode: null,
            failureMessage: null,
            failedAt: null,
          },
          {
            merge: true,
          },
        );

        return {
          acquired: true,
          reason,
          attemptCount,
          claimToken:
            claimToken.trim(),
          claimedAt,
          leaseExpiresAt,
        };
      },
    );
  }

  async function complete({
    identity,
    claimToken,
    processorRunId,
    manifestPath,
    completedAt = now(),
  }) {
    const ref =
      db.doc(identity.firestorePath);

    return db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(ref);

        if (!snapshot.exists) {
          throw new Error(
            'RUN_CLAIM_NOT_FOUND: Processing claim is missing.',
          );
        }

        const data =
          snapshot.data() || {};

        if (
          data.claimToken !==
          claimToken
        ) {
          throw new Error(
            'RUN_CLAIM_LOST: Processing claim is owned by another invocation.',
          );
        }

        const date =
          validDate(
            completedAt,
            'RUN_COMPLETE_DATE_INVALID',
          );

        transaction.update(ref, {
          status: 'completed',
          processorRunId:
            String(
              processorRunId || '',
            ).trim() || null,
          manifestPath:
            String(
              manifestPath || '',
            ).trim() || null,
          completedAt: date,
          leaseExpiresAt: date,
          failureCode: null,
          failureMessage: null,
          failedAt: null,
          updatedAt: date,
        });

        return {
          completed: true,
          runId: identity.runId,
        };
      },
    );
  }

  async function fail({
    identity,
    claimToken,
    error,
    failedAt = now(),
  }) {
    const ref =
      db.doc(identity.firestorePath);

    return db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(ref);

        if (!snapshot.exists) {
          throw new Error(
            'RUN_CLAIM_NOT_FOUND: Processing claim is missing.',
          );
        }

        const data =
          snapshot.data() || {};

        if (
          data.claimToken !==
          claimToken
        ) {
          throw new Error(
            'RUN_CLAIM_LOST: Processing claim is owned by another invocation.',
          );
        }

        const message =
          error instanceof Error
            ? error.message
            : String(
                error ||
                'Unknown processing failure.',
              );

        const separator =
          message.indexOf(':');

        const failureCode =
          separator > 0
            ? message
                .slice(0, separator)
                .trim()
            : 'IMG_PROCESSING_FAILED';

        const date =
          validDate(
            failedAt,
            'RUN_FAILURE_DATE_INVALID',
          );

        transaction.update(ref, {
          status: 'failed',
          failureCode:
            failureCode ||
            'IMG_PROCESSING_FAILED',
          failureMessage:
            message.trim() ||
            'Unknown processing failure.',
          failedAt: date,
          leaseExpiresAt: date,
          updatedAt: date,
        });

        return {
          failed: true,
          runId: identity.runId,
          failureCode,
        };
      },
    );
  }

  async function renew({
    identity,
    claimToken,
    renewedAt = now(),
  }) {
    if (
      !identity ||
      !identity.firestorePath ||
      !identity.runId
    ) {
      throw new Error(
        'RUN_IDENTITY_INVALID: Event identity is required.',
      );
    }

    if (
      typeof claimToken !== 'string' ||
      claimToken.trim().length === 0
    ) {
      throw new Error(
        'RUN_CLAIM_TOKEN_INVALID: Claim token is required.',
      );
    }

    const ref =
      db.doc(identity.firestorePath);

    return db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(ref);

        if (!snapshot.exists) {
          throw new Error(
            'RUN_CLAIM_NOT_FOUND: Processing claim is missing.',
          );
        }

        const data =
          snapshot.data() || {};

        if (
          data.status !== 'processing' ||
          data.claimToken !==
            claimToken.trim()
        ) {
          throw new Error(
            'RUN_CLAIM_LOST: Processing claim is owned by another invocation.',
          );
        }

        const date =
          validDate(
            renewedAt,
            'RUN_RENEW_DATE_INVALID',
          );

        const leaseExpiresAt =
          new Date(
            date.getTime() +
            normalizedLeaseMs,
          );

        transaction.update(ref, {
          leaseExpiresAt,
          updatedAt: date,
        });

        return {
          renewed: true,
          runId: identity.runId,
          claimToken:
            claimToken.trim(),
          renewedAt: date,
          leaseExpiresAt,
        };
      },
    );
  }

  return {
    claim,
    renew,
    complete,
    fail,
  };
}

module.exports = {
  DEFAULT_LEASE_MS,
  createProcessingRunStore,
};
