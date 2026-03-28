//
//  PersistenceController.swift
//  Medicine Reminder
//
//  Created by Codex on 28.03.2026.
//

import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "MedicineReminder", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store could not be loaded: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let localUser = NSEntityDescription()
        localUser.name = "LocalUser"
        localUser.managedObjectClassName = NSStringFromClass(LocalUser.self)
        localUser.properties = [
            makeAttribute(name: "userId", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "isGuest", type: .booleanAttributeType, isOptional: false),
            makeAttribute(name: "isActive", type: .booleanAttributeType, isOptional: false),
            makeAttribute(name: "createdAt", type: .dateAttributeType, isOptional: false)
        ]
        localUser.uniquenessConstraints = [["userId"]]

        let localMedication = NSEntityDescription()
        localMedication.name = "LocalMedication"
        localMedication.managedObjectClassName = NSStringFromClass(LocalMedication.self)
        localMedication.properties = [
            makeAttribute(name: "medicationId", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "userId", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "name", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "dosage", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "selectedWeekdaysData", type: .binaryDataAttributeType, isOptional: false),
            makeAttribute(name: "reminderTimesData", type: .binaryDataAttributeType, isOptional: false),
            makeAttribute(name: "updatedAt", type: .dateAttributeType, isOptional: false),
            makeAttribute(name: "version", type: .integer64AttributeType, isOptional: false),
            makeAttribute(name: "deletedFlag", type: .booleanAttributeType, isOptional: false)
        ]
        localMedication.uniquenessConstraints = [["medicationId"]]

        let localMedicationLog = NSEntityDescription()
        localMedicationLog.name = "LocalMedicationLog"
        localMedicationLog.managedObjectClassName = NSStringFromClass(LocalMedicationLog.self)
        localMedicationLog.properties = [
            makeAttribute(name: "logId", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "userId", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "medicationId", type: .stringAttributeType, isOptional: false),
            makeAttribute(name: "scheduledTime", type: .dateAttributeType, isOptional: false),
            makeAttribute(name: "taken", type: .booleanAttributeType, isOptional: false),
            makeAttribute(name: "takenAt", type: .dateAttributeType, isOptional: true),
            makeAttribute(name: "updatedAt", type: .dateAttributeType, isOptional: false),
            makeAttribute(name: "syncStatus", type: .stringAttributeType, isOptional: false)
        ]
        localMedicationLog.uniquenessConstraints = [["logId"]]

        model.entities = [localUser, localMedication, localMedicationLog]
        return model
    }

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }
}
