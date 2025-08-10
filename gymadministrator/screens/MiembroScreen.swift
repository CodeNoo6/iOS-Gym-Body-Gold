//
//  MiembrosViews.swift
//  gymadministrator
//
//  Created by Ruben Camargo on 24/07/25.
//

import SwiftUI

// MARK: - Miembros List View
struct MiembrosListView: View {
    @StateObject private var miembroManager = MiembroManager()
    @State private var searchText = ""
    @State private var showingAddMember = false
    @State private var selectedMember: Miembro?
    
    var filteredMiembros: [Miembro] {
        miembroManager.searchMiembros(query: searchText)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                if miembroManager.isLoading {
                    ProgressView("Cargando miembros...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredMiembros.isEmpty {
                    EmptyMembersView()
                } else {
                    List {
                        ForEach(filteredMiembros) { miembro in
                            MiembroRowView(miembro: miembro)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMember = miembro
                                }
                        }
                        .onDelete(perform: deleteMiembros)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Miembros")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddMember = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.brandGold)
                    }
                }
            }
            .sheet(isPresented: $showingAddMember) {
                AddEditMiembroView(miembroManager: miembroManager)
            }
            .sheet(item: $selectedMember) { miembro in
                MiembroDetailView(miembro: miembro, miembroManager: miembroManager)
            }
            .alert("Error", isPresented: .constant(!miembroManager.errorMessage.isEmpty)) {
                Button("OK") {
                    miembroManager.errorMessage = ""
                }
            } message: {
                Text(miembroManager.errorMessage)
            }
        }
    }
    
    private func deleteMiembros(offsets: IndexSet) {
        for index in offsets {
            let miembro = filteredMiembros[index]
            Task {
                await miembroManager.deleteMiembro(miembro)
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.brandGold)
            
            TextField("Buscar miembros...", text: $text)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.brandWhite.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brandGold.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Miembro Row View
struct MiembroRowView: View {
    let miembro: Miembro
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(LinearGradient.brandPrimary)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(miembro.nombre.prefix(1) + miembro.apellido.prefix(1))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.brandBlack)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(miembro.nombreCompleto)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(miembro.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(miembro.tipoDocumentoDescripcion)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.brandGold.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(.brandGold)
                    
                    Text("Edad: \(miembro.edad)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status
            VStack {
                Image(systemName: miembro.activo ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(miembro.activo ? .brandSuccess : .brandError)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty Members View
struct EmptyMembersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.brandGold.opacity(0.5))
            
            Text("No hay miembros registrados")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Agrega el primer miembro de tu gimnasio")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Add/Edit Miembro View
struct AddEditMiembroView: View {
    @ObservedObject var miembroManager: MiembroManager
    @Environment(\.presentationMode) var presentationMode
    
    let miembro: Miembro?
    
    @State private var nombre = ""
    @State private var apellido = ""
    @State private var email = ""
    @State private var telefono = ""
    @State private var direccion = ""
    @State private var numeroDocumento = ""
    @State private var cedula = ""
    @State private var fechaNacimiento = Date()
    @State private var edad = 18
    @State private var peso = 70.0
    @State private var estatura = 1.70
    @State private var selectedTipoDocumento = 1
    @State private var selectedGenero = 1
    @State private var isLoading = false
    @State private var showingDatePicker = false
    
    private var isEditing: Bool {
        miembro != nil
    }
    
    init(miembroManager: MiembroManager, miembro: Miembro? = nil) {
        self.miembroManager = miembroManager
        self.miembro = miembro
        
        if let miembro = miembro {
            _nombre = State(initialValue: miembro.nombre)
            _apellido = State(initialValue: miembro.apellido)
            _email = State(initialValue: miembro.email)
            _telefono = State(initialValue: miembro.telefono ?? "")
            _direccion = State(initialValue: miembro.direccion ?? "")
            _numeroDocumento = State(initialValue: miembro.numeroDocumento)
            _cedula = State(initialValue: miembro.cedula)
            _edad = State(initialValue: miembro.edad)
            _peso = State(initialValue: miembro.peso)
            _estatura = State(initialValue: miembro.estatura)
            _selectedTipoDocumento = State(initialValue: miembro.idTipoDocumento)
            _selectedGenero = State(initialValue: miembro.idGenero)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Información Personal") {
                    TextField("Nombre", text: $nombre)
                    TextField("Apellido", text: $apellido)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Teléfono", text: $telefono)
                        .keyboardType(.phonePad)
                    TextField("Dirección", text: $direccion)
                }
                
                Section("Documentación") {
                    Picker("Tipo de Documento", selection: $selectedTipoDocumento) {
                        ForEach(miembroManager.tiposDocumento, id: \.idTipoDocumento) { tipo in
                            Text(tipo.descripcion).tag(tipo.idTipoDocumento)
                        }
                    }
                    TextField("Número de Documento", text: $numeroDocumento)
                    TextField("Cédula", text: $cedula)
                }
                
                Section("Información Física") {
                    Picker("Género", selection: $selectedGenero) {
                        ForEach(miembroManager.generos, id: \.idGenero) { genero in
                            Text(genero.descripcion).tag(genero.idGenero)
                        }
                    }
                    
                    HStack {
                        Text("Edad:")
                        Spacer()
                        TextField("Edad", value: $edad, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Peso (kg):")
                        Spacer()
                        TextField("Peso", value: $peso, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Estatura (m):")
                        Spacer()
                        TextField("Estatura", value: $estatura, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        HStack {
                            Text("Fecha de Nacimiento:")
                            Spacer()
                            Text(fechaNacimiento, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Miembro" : "Nuevo Miembro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Actualizar" : "Guardar") {
                        saveMiembro()
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(selectedDate: $fechaNacimiento, showingDatePicker: $showingDatePicker)
            }
        }
    }
    
    private var isFormValid: Bool {
        !nombre.isEmpty && !apellido.isEmpty && !email.isEmpty &&
        !numeroDocumento.isEmpty && !cedula.isEmpty && email.isValidEmail
    }
    
    private func saveMiembro() {
        isLoading = true
        
        let newMiembro = Miembro(
            idMiembro: miembro?.idMiembro ?? 0,
            idTipoDocumento: selectedTipoDocumento,
            numeroDocumento: numeroDocumento,
            nombre: nombre,
            apellido: apellido,
            email: email,
            telefono: telefono.isEmpty ? nil : telefono,
            fechaNacimiento: DateFormatter.gymDate.string(from: fechaNacimiento),
            direccion: direccion.isEmpty ? nil : direccion,
            fechaRegistro: miembro?.fechaRegistro ?? Date().gymDateString,
            idGenero: selectedGenero,
            edad: edad,
            peso: peso,
            estatura: estatura,
            cedula: cedula,
            activo: miembro?.activo ?? true
        )
        
        let (isValid, errorMessage) = newMiembro.isValid()
        
        if !isValid {
            miembroManager.errorMessage = errorMessage
            isLoading = false
            return
        }
        
        Task {
            let success: Bool
            if isEditing {
                success = await miembroManager.updateMiembro(newMiembro)
            } else {
                success = await miembroManager.addMiembro(newMiembro)
            }
            
            isLoading = false
            
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Date Picker View
struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var showingDatePicker: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Fecha de Nacimiento",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Fecha de Nacimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        showingDatePicker = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        showingDatePicker = false
                    }
                    .foregroundColor(.brandGold)
                }
            }
        }
    }
}

// MARK: - Miembro Detail View
struct MiembroDetailView: View {
    let miembro: Miembro
    @ObservedObject var miembroManager: MiembroManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @StateObject private var membresiaManager = MembresiaManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 16) {
                        // Avatar
                        Circle()
                            .fill(LinearGradient.brandPrimary)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(miembro.nombre.prefix(1) + miembro.apellido.prefix(1))
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandBlack)
                            )
                        
                        VStack(spacing: 8) {
                            Text(miembro.nombreCompleto)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(miembro.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                StatusBadge(
                                    text: miembro.activo ? "ACTIVO" : "INACTIVO",
                                    color: miembro.activo ? .brandSuccess : .brandError
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color.brandWhite)
                    .cornerRadius(16)
                    .brandShadow()
                    
                    // Personal Info Card
                    InfoCard(title: "Información Personal", icon: "person.fill") {
                        InfoRow(label: "Nombre completo", value: miembro.nombreCompleto)
                        InfoRow(label: "Email", value: miembro.email)
                        InfoRow(label: "Teléfono", value: miembro.telefono ?? "No especificado")
                        InfoRow(label: "Dirección", value: miembro.direccion ?? "No especificada")
                        InfoRow(label: "Fecha de nacimiento", value: miembro.fechaNacimiento ?? "No especificada")
                        InfoRow(label: "Género", value: miembro.generoDescripcion)
                    }
                    
                    // Document Info Card
                    InfoCard(title: "Documentación", icon: "doc.text.fill") {
                        InfoRow(label: "Tipo de documento", value: miembro.tipoDocumentoDescripcion)
                        InfoRow(label: "Número de documento", value: miembro.numeroDocumento)
                        InfoRow(label: "Cédula", value: miembro.cedula)
                        InfoRow(label: "Fecha de registro", value: miembro.fechaRegistro)
                    }
                    
                    // Physical Info Card
                    InfoCard(title: "Información Física", icon: "figure.walk") {
                        InfoRow(label: "Edad", value: "\(miembro.edad) años")
                        InfoRow(label: "Peso", value: String(format: "%.1f kg", miembro.peso))
                        InfoRow(label: "Estatura", value: String(format: "%.2f m", miembro.estatura))
                        InfoRow(label: "IMC", value: String(format: "%.1f", calculateIMC()))
                    }
                    
                    // Membresia Info Card
                    MembresiaInfoCard(miembro: miembro, membresiaManager: membresiaManager)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Detalle del Miembro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingEditView = true
                        }) {
                            Label("Editar", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("Eliminar", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.brandGold)
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                AddEditMiembroView(miembroManager: miembroManager, miembro: miembro)
            }
            .alert("Eliminar Miembro", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    Task {
                        let success = await miembroManager.deleteMiembro(miembro)
                        if success {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            } message: {
                Text("¿Estás seguro de que quieres eliminar a \(miembro.nombreCompleto)? Esta acción no se puede deshacer.")
            }
        }
        .onAppear {
            Task {
                await membresiaManager.loadMembresias()
            }
        }
    }
    
    private func calculateIMC() -> Double {
        return miembro.peso / (miembro.estatura * miembro.estatura)
    }
}

// MARK: - Helper Views

struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandGold)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                content
            }
        }
        .padding()
        .background(Color.brandWhite)
        .cornerRadius(16)
        .brandShadow()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct MembresiaInfoCard: View {
    let miembro: Miembro
    @ObservedObject var membresiaManager: MembresiaManager
    
    var membresia: Membresia? {
        membresiaManager.getMembresiaForMiembro(idMiembro: miembro.idMiembro)
    }
    
    var body: some View {
        InfoCard(title: "Membresía", icon: "creditcard.fill") {
            if let membresia = membresia {
                InfoRow(label: "Tipo", value: membresia.tipoMembresia)
                InfoRow(label: "Estado", value: membresia.estadoDescripcion)
                InfoRow(label: "Fecha inicio", value: membresia.fechaInicio)
                InfoRow(label: "Fecha vencimiento", value: membresia.fechaVencimiento)
                InfoRow(label: "Precio", value: "$\(Int(membresia.precio).formatted())")
                
                if let dias = membresia.diasRestantes {
                    InfoRow(label: "Días restantes", value: "\(dias) días")
                }
            } else {
                Text("No tiene membresía activa")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MiembrosListView()
}
