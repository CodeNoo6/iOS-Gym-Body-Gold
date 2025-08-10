//
//  FirebaseModels.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Data Models

struct Miembro: Identifiable, Codable {
    @DocumentID var id: String?
    let idMiembro: Int
    let idTipoDocumento: Int
    let numeroDocumento: String
    let nombre: String
    let apellido: String
    let email: String
    let telefono: String?
    let fechaNacimiento: String?
    let direccion: String?
    let fechaRegistro: String
    let idGenero: Int
    let edad: Int
    let peso: Double
    let estatura: Double
    let cedula: String
    let activo: Bool
    
    init(
        idMiembro: Int = 0,
        idTipoDocumento: Int,
        numeroDocumento: String,
        nombre: String,
        apellido: String,
        email: String,
        telefono: String? = nil,
        fechaNacimiento: String? = nil,
        direccion: String? = nil,
        fechaRegistro: String? = nil,
        idGenero: Int,
        edad: Int,
        peso: Double,
        estatura: Double,
        cedula: String,
        activo: Bool = true
    ) {
        self.idMiembro = idMiembro
        self.idTipoDocumento = idTipoDocumento
        self.numeroDocumento = numeroDocumento
        self.nombre = nombre
        self.apellido = apellido
        self.email = email
        self.telefono = telefono
        self.fechaNacimiento = fechaNacimiento
        self.direccion = direccion
        self.fechaRegistro = fechaRegistro ?? DateFormatter.gymDate.string(from: Date())
        self.idGenero = idGenero
        self.edad = edad
        self.peso = peso
        self.estatura = estatura
        self.cedula = cedula
        self.activo = activo
    }
    
    var nombreCompleto: String {
        return "\(nombre) \(apellido)"
    }
    
    var tipoDocumentoDescripcion: String {
        switch idTipoDocumento {
        case 1: return "Cédula de Ciudadanía"
        case 2: return "Cédula de Extranjería"
        case 3: return "Pasaporte"
        case 4: return "Tarjeta de Identidad"
        default: return "Desconocido"
        }
    }
    
    var generoDescripcion: String {
        switch idGenero {
        case 1: return "Masculino"
        case 2: return "Femenino"
        case 3: return "Otro"
        default: return "No especificado"
        }
    }
}

struct TipoDocumento: Identifiable, Codable {
    @DocumentID var id: String?
    let idTipoDocumento: Int
    let descripcion: String
    let activo: Bool
}

struct Genero: Identifiable, Codable {
    @DocumentID var id: String?
    let idGenero: Int
    let descripcion: String
    let activo: Bool
}

struct Membresia: Identifiable, Codable {
    @DocumentID var id: String?
    let idMembresia: Int
    let idMiembro: Int
    let tipoMembresia: String
    let fechaInicio: String
    let fechaVencimiento: String
    let precio: Double
    let activa: Bool
    let diasRestantes: Int?
    
    var estadoDescripcion: String {
        if let dias = diasRestantes {
            if dias <= 0 {
                return "VENCIDA"
            } else if dias <= 5 {
                return "POR VENCER"
            } else {
                return "ACTIVA"
            }
        }
        return activa ? "ACTIVA" : "INACTIVA"
    }
    
    var colorEstado: String {
        if let dias = diasRestantes {
            if dias <= 0 { return "red" }
            else if dias <= 5 { return "orange" }
            else { return "green" }
        }
        return activa ? "green" : "gray"
    }
}

// MARK: - Firebase Managers

@MainActor
class MiembroManager: ObservableObject {
    @Published var miembros: [Miembro] = []
    @Published var tiposDocumento: [TipoDocumento] = []
    @Published var generos: [Genero] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    init() {
        loadInitialData()
    }
    
    // MARK: - Load Initial Data
    func loadInitialData() {
        Task {
            await loadTiposDocumento()
            await loadGeneros()
            await loadMiembros()
        }
    }
    
    // MARK: - Miembros CRUD
    
    func loadMiembros() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("miembros")
                .whereField("activo", isEqualTo: true)
                .order(by: "fechaRegistro", descending: true)
                .getDocuments()
            
            miembros = try snapshot.documents.compactMap { document in
                try document.data(as: Miembro.self)
            }
            
        } catch {
            errorMessage = "Error al cargar miembros: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addMiembro(_ miembro: Miembro) async -> Bool {
        isLoading = true
        
        do {
            // Generar ID único para el miembro
            let nextId = await getNextMiembroId()
            var newMiembro = miembro
            // Note: Necesitarías crear una versión mutable del struct o usar un approach diferente
            
            let miembroData: [String: Any] = [
                "idMiembro": nextId,
                "idTipoDocumento": miembro.idTipoDocumento,
                "numeroDocumento": miembro.numeroDocumento,
                "nombre": miembro.nombre,
                "apellido": miembro.apellido,
                "email": miembro.email,
                "telefono": miembro.telefono ?? "",
                "fechaNacimiento": miembro.fechaNacimiento ?? "",
                "direccion": miembro.direccion ?? "",
                "fechaRegistro": miembro.fechaRegistro,
                "idGenero": miembro.idGenero,
                "edad": miembro.edad,
                "peso": miembro.peso,
                "estatura": miembro.estatura,
                "cedula": miembro.cedula,
                "activo": miembro.activo
            ]
            
            try await db.collection("miembros").addDocument(data: miembroData)
            await loadMiembros() // Recargar lista
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Error al agregar miembro: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func updateMiembro(_ miembro: Miembro) async -> Bool {
        guard let documentId = miembro.id else { return false }
        
        isLoading = true
        
        do {
            let miembroData: [String: Any] = [
                "idMiembro": miembro.idMiembro,
                "idTipoDocumento": miembro.idTipoDocumento,
                "numeroDocumento": miembro.numeroDocumento,
                "nombre": miembro.nombre,
                "apellido": miembro.apellido,
                "email": miembro.email,
                "telefono": miembro.telefono ?? "",
                "fechaNacimiento": miembro.fechaNacimiento ?? "",
                "direccion": miembro.direccion ?? "",
                "fechaRegistro": miembro.fechaRegistro,
                "idGenero": miembro.idGenero,
                "edad": miembro.edad,
                "peso": miembro.peso,
                "estatura": miembro.estatura,
                "cedula": miembro.cedula,
                "activo": miembro.activo
            ]
            
            try await db.collection("miembros").document(documentId).updateData(miembroData)
            await loadMiembros()
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Error al actualizar miembro: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func deleteMiembro(_ miembro: Miembro) async -> Bool {
        guard let documentId = miembro.id else { return false }
        
        isLoading = true
        
        do {
            // Soft delete - solo marcar como inactivo
            try await db.collection("miembros").document(documentId).updateData([
                "activo": false
            ])
            
            await loadMiembros()
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Error al eliminar miembro: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func searchMiembros(query: String) -> [Miembro] {
        if query.isEmpty {
            return miembros
        }
        
        return miembros.filter { miembro in
            miembro.nombre.localizedCaseInsensitiveContains(query) ||
            miembro.apellido.localizedCaseInsensitiveContains(query) ||
            miembro.email.localizedCaseInsensitiveContains(query) ||
            miembro.numeroDocumento.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getNextMiembroId() async -> Int {
        do {
            let snapshot = try await db.collection("miembros")
                .order(by: "idMiembro", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            if let lastMiembro = snapshot.documents.first,
               let lastId = lastMiembro.data()["idMiembro"] as? Int {
                return lastId + 1
            }
            
            return 1 // Primer miembro
            
        } catch {
            print("Error getting next ID: \(error)")
            return Int(Date().timeIntervalSince1970) // Fallback
        }
    }
    
    // MARK: - Load Reference Data
    
    private func loadTiposDocumento() async {
        do {
            let snapshot = try await db.collection("tiposDocumento")
                .whereField("activo", isEqualTo: true)
                .getDocuments()
            
            tiposDocumento = try snapshot.documents.compactMap { document in
                try document.data(as: TipoDocumento.self)
            }
            
            // Si no hay tipos de documento, crear los básicos
            if tiposDocumento.isEmpty {
                await createDefaultTiposDocumento()
            }
            
        } catch {
            errorMessage = "Error al cargar tipos de documento: \(error.localizedDescription)"
        }
    }
    
    private func loadGeneros() async {
        do {
            let snapshot = try await db.collection("generos")
                .whereField("activo", isEqualTo: true)
                .getDocuments()
            
            generos = try snapshot.documents.compactMap { document in
                try document.data(as: Genero.self)
            }
            
            // Si no hay géneros, crear los básicos
            if generos.isEmpty {
                await createDefaultGeneros()
            }
            
        } catch {
            errorMessage = "Error al cargar géneros: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Create Default Data
    
    private func createDefaultTiposDocumento() async {
        let defaultTipos = [
            ["idTipoDocumento": 1, "descripcion": "Cédula de Ciudadanía", "activo": true],
            ["idTipoDocumento": 2, "descripcion": "Cédula de Extranjería", "activo": true],
            ["idTipoDocumento": 3, "descripcion": "Pasaporte", "activo": true],
            ["idTipoDocumento": 4, "descripcion": "Tarjeta de Identidad", "activo": true]
        ]
        
        for tipo in defaultTipos {
            do {
                try await db.collection("tiposDocumento").addDocument(data: tipo)
            } catch {
                print("Error creating default tipo documento: \(error)")
            }
        }
        
        await loadTiposDocumento()
    }
    
    private func createDefaultGeneros() async {
        let defaultGeneros = [
            ["idGenero": 1, "descripcion": "Masculino", "activo": true],
            ["idGenero": 2, "descripcion": "Femenino", "activo": true],
            ["idGenero": 3, "descripcion": "Otro", "activo": true]
        ]
        
        for genero in defaultGeneros {
            do {
                try await db.collection("generos").addDocument(data: genero)
            } catch {
                print("Error creating default genero: \(error)")
            }
        }
        
        await loadGeneros()
    }
}

// MARK: - Membresia Manager

@MainActor
class MembresiaManager: ObservableObject {
    @Published var membresias: [Membresia] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    func loadMembresias() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("membresias")
                .whereField("activa", isEqualTo: true)
                .order(by: "fechaVencimiento", descending: false)
                .getDocuments()
            
            membresias = try snapshot.documents.compactMap { document in
                try document.data(as: Membresia.self)
            }
            
        } catch {
            errorMessage = "Error al cargar membresías: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func getMembresiaForMiembro(idMiembro: Int) -> Membresia? {
        return membresias.first { $0.idMiembro == idMiembro && $0.activa }
    }
    
    func addMembresia(_ membresia: Membresia) async -> Bool {
        do {
            let membresiaData: [String: Any] = [
                "idMembresia": membresia.idMembresia,
                "idMiembro": membresia.idMiembro,
                "tipoMembresia": membresia.tipoMembresia,
                "fechaInicio": membresia.fechaInicio,
                "fechaVencimiento": membresia.fechaVencimiento,
                "precio": membresia.precio,
                "activa": membresia.activa,
                "diasRestantes": membresia.diasRestantes ?? 0
            ]
            
            try await db.collection("membresias").addDocument(data: membresiaData)
            await loadMembresias()
            return true
            
        } catch {
            errorMessage = "Error al agregar membresía: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let gymDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let gymDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

extension Date {
    var gymDateString: String {
        return DateFormatter.gymDate.string(from: self)
    }
    
    var gymDateTimeString: String {
        return DateFormatter.gymDateTime.string(from: self)
    }
}

// MARK: - Validation Extensions

extension Miembro {
    func isValid() -> (Bool, String) {
        if nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "El nombre es requerido")
        }
        
        if apellido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "El apellido es requerido")
        }
        
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "El email es requerido")
        }
        
        if !email.isValidEmail {
            return (false, "El email no tiene un formato válido")
        }
        
        if numeroDocumento.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "El número de documento es requerido")
        }
        
        if cedula.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "La cédula es requerida")
        }
        
        if edad < 1 || edad > 120 {
            return (false, "La edad debe estar entre 1 y 120 años")
        }
        
        if peso <= 0 || peso > 500 {
            return (false, "El peso debe ser un valor válido")
        }
        
        if estatura <= 0 || estatura > 3.0 {
            return (false, "La estatura debe ser un valor válido")
        }
        
        return (true, "")
    }
}

extension String {
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
}
