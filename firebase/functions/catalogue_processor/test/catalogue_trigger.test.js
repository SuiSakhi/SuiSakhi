"use strict";

const test = require("node:test");

const assert = require("node:assert/strict");

const { createCatalogueStorageTrigger } = require("../catalogue_trigger");

const { TARGET_BUCKET, TARGET_REGION } = require("../firebase_worker");

function triggerDoubles() {
  const calls = {
    regions: [],
    buckets: [],
    finalizedHandlers: [],
  };

  const functions = {
    logger: {
      info() {},
      error() {},
    },

    region(region) {
      calls.regions.push(region);

      return {
        storage: {
          bucket(bucketName) {
            calls.buckets.push(bucketName);

            return {
              object() {
                return {
                  onFinalize(handler) {
                    calls.finalizedHandlers.push(handler);

                    return {
                      triggerType: "storage.onFinalize",
                      region,
                      bucket: bucketName,
                      handler,
                    };
                  },
                };
              },
            };
          },
        },
      };
    },
  };

  const bucket = {
    file() {
      throw new Error(
        "Storage must not be accessed during trigger registration.",
      );
    },
  };

  const db = {
    doc() {
      throw new Error(
        "Firestore must not be accessed during trigger registration.",
      );
    },

    async runTransaction() {
      throw new Error("Transaction must not run during trigger registration.");
    },
  };

  const admin = {
    storage() {
      return {
        bucket(bucketName) {
          assert.equal(bucketName, TARGET_BUCKET);

          return bucket;
        },
      };
    },

    firestore() {
      return db;
    },
  };

  return {
    calls,
    functions,
    admin,
  };
}

test("registers a bucket-scoped onFinalize trigger", () => {
  const fake = triggerDoubles();

  const trigger = createCatalogueStorageTrigger({
    functions: fake.functions,
    admin: fake.admin,
  });

  assert.equal(trigger.triggerType, "storage.onFinalize");

  assert.equal(trigger.region, TARGET_REGION);

  assert.equal(trigger.bucket, TARGET_BUCKET);

  assert.deepEqual(fake.calls.regions, [TARGET_REGION]);

  assert.deepEqual(fake.calls.buckets, [TARGET_BUCKET]);

  assert.equal(fake.calls.finalizedHandlers.length, 1);

  assert.equal(typeof trigger.handler, "function");
});

test("rejects a missing Functions dependency", () => {
  assert.throws(
    () =>
      createCatalogueStorageTrigger({
        functions: null,
        admin: {},
      }),
    /TRIGGER_FUNCTIONS_INVALID/,
  );
});

test("rejects a missing Admin dependency", () => {
  const fake = triggerDoubles();

  assert.throws(
    () =>
      createCatalogueStorageTrigger({
        functions: fake.functions,
        admin: null,
      }),
    /TRIGGER_ADMIN_INVALID/,
  );
});
