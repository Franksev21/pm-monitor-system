import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'clients';

  // Obtener todos los clientes
  Stream<List<ClientModel>> getClients() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ClientModel.fromJson(doc.data()))
          .toList();
    });
  }

  // Obtener cliente por ID
  Future<ClientModel?> getClientById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return ClientModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print('Error getting client: $e');
    }
    return null;
  }

  // Crear cliente
  Future<String?> createClient(ClientModel client) async {
    try {
      final doc = _firestore.collection(_collection).doc();
      final clientWithId = client.copyWith(id: doc.id);
      await doc.set(clientWithId.toJson());
      return doc.id;
    } catch (e) {
      print('Error creating client: $e');
      throw 'Error al crear cliente: $e';
    }
  }

  // Actualizar cliente
  Future<void> updateClient(ClientModel client) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(client.id)
          .update(client.toJson());
    } catch (e) {
      print('Error updating client: $e');
      throw 'Error al actualizar cliente: $e';
    }
  }

  // Eliminar cliente
  Future<void> deleteClient(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('Error deleting client: $e');
      throw 'Error al eliminar cliente: $e';
    }
  }

  // Buscar clientes por nombre
  Future<List<ClientModel>> searchClients(String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => ClientModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error searching clients: $e');
      return [];
    }
  }

  // Filtrar clientes por estado
  Stream<List<ClientModel>> getClientsByStatus(ClientStatus status) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: status.name)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ClientModel.fromJson(doc.data()))
          .toList();
    });
  }

  // Filtrar clientes por tipo
  Stream<List<ClientModel>> getClientsByType(ClientType type) {
    return _firestore
        .collection(_collection)
        .where('type', isEqualTo: type.name)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ClientModel.fromJson(doc.data()))
          .toList();
    });
  }

  // Crear clientes de prueba
  Future<void> createMockClients(String createdBy) async {
    final mockClients = [
      ClientModel(
        id: '',
        name: 'Banco Popular Dominicano',
        email: 'contacto@bpd.com.do',
        phone: '+1-809-544-5000',
        website: 'www.popularenlinea.com',
        taxId: '101-02345-6',
        type: ClientType.enterprise,
        status: ClientStatus.active,
        mainAddress: AddressModel(
          street: 'Av. John F. Kennedy No. 20',
          city: 'Santo Domingo',
          state: 'Distrito Nacional',
          country: 'República Dominicana',
          zipCode: '10205',
        ),
        branches: [
          BranchModel(
            id: 'branch_1',
            name: 'Sucursal Plaza Central',
            address: AddressModel(
              street: 'Av. 27 de Febrero No. 1762',
              city: 'Santo Domingo',
              state: 'Distrito Nacional',
              country: 'República Dominicana',
              zipCode: '10203',
            ),
            managerName: 'María Rodríguez',
            managerPhone: '+1-809-555-0101',
          ),
          BranchModel(
            id: 'branch_2',
            name: 'Sucursal Agora Mall',
            address: AddressModel(
              street: 'Av. John F. Kennedy, Agora Mall',
              city: 'Santo Domingo',
              state: 'Distrito Nacional',
              country: 'República Dominicana',
              zipCode: '10205',
            ),
            managerName: 'Carlos Mejía',
            managerPhone: '+1-809-555-0102',
          ),
        ],
        contacts: [
          ContactModel(
            id: 'contact_1',
            name: 'Luis García',
            email: 'luis.garcia@bpd.com.do',
            phone: '+1-809-555-0111',
            position: 'Gerente de Operaciones',
            type: ContactType.management,
            isPrimary: true,
          ),
          ContactModel(
            id: 'contact_2',
            name: 'Ana Martínez',
            email: 'ana.martinez@bpd.com.do',
            phone: '+1-809-555-0112',
            position: 'Jefe de Mantenimiento',
            type: ContactType.technical,
          ),
        ],
        notes:
            'Cliente corporativo con múltiples sucursales. Mantenimiento mensual de sistemas de climatización.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
      ),
      ClientModel(
        id: '',
        name: 'Claro Dominicana',
        email: 'atencion@claro.com.do',
        phone: '+1-809-220-1111',
        website: 'www.claro.com.do',
        taxId: '101-11111-1',
        type: ClientType.enterprise,
        status: ClientStatus.active,
        mainAddress: AddressModel(
          street: 'Av. Abraham Lincoln No. 452',
          city: 'Santo Domingo',
          state: 'Distrito Nacional',
          country: 'República Dominicana',
          zipCode: '10201',
        ),
        branches: [
          BranchModel(
            id: 'branch_claro_1',
            name: 'Data Center Principal',
            address: AddressModel(
              street: 'Zona Industrial de Herrera',
              city: 'Santo Domingo',
              state: 'Distrito Nacional',
              country: 'República Dominicana',
              zipCode: '10301',
            ),
            managerName: 'Pedro Vásquez',
            managerPhone: '+1-809-555-0201',
          ),
        ],
        contacts: [
          ContactModel(
            id: 'contact_claro_1',
            name: 'Roberto Díaz',
            email: 'roberto.diaz@claro.com.do',
            phone: '+1-809-555-0211',
            position: 'Director de Infraestructura',
            type: ContactType.management,
            isPrimary: true,
          ),
        ],
        notes:
            'Cliente de telecomunicaciones. Crítico: sistemas 24/7, mantenimiento semanal.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
      ),
      ClientModel(
        id: '',
        name: 'Hotel Casa Colonial',
        email: 'info@casacolonial.com.do',
        phone: '+1-809-688-7799',
        website: 'www.casacolonial.com.do',
        taxId: '131-22222-2',
        type: ClientType.medium,
        status: ClientStatus.active,
        mainAddress: AddressModel(
          street: 'Calle Duarte No. 232, Zona Colonial',
          city: 'Santo Domingo',
          state: 'Distrito Nacional',
          country: 'República Dominicana',
          zipCode: '10210',
        ),
        branches: [],
        contacts: [
          ContactModel(
            id: 'contact_hotel_1',
            name: 'Carmen Peña',
            email: 'carmen.pena@casacolonial.com.do',
            phone: '+1-809-555-0301',
            position: 'Gerente General',
            type: ContactType.management,
            isPrimary: true,
          ),
        ],
        notes:
            'Hotel boutique. Mantenimiento trimestral de aires acondicionados y generadores.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
      ),
      ClientModel(
        id: '',
        name: 'Supermercados Nacional',
        email: 'mantenimiento@nacional.com.do',
        phone: '+1-809-566-9999',
        website: 'www.nacional.com.do',
        taxId: '101-33333-3',
        type: ClientType.large,
        status: ClientStatus.active,
        mainAddress: AddressModel(
          street: 'Av. Tiradentes No. 30',
          city: 'Santo Domingo',
          state: 'Distrito Nacional',
          country: 'República Dominicana',
          zipCode: '10204',
        ),
        branches: [
          BranchModel(
            id: 'branch_nacional_1',
            name: 'Nacional Naco',
            address: AddressModel(
              street: 'Av. Tiradentes esq. Roberto Pastoriza',
              city: 'Santo Domingo',
              state: 'Distrito Nacional',
              country: 'República Dominicana',
              zipCode: '10204',
            ),
            managerName: 'Miguel Santos',
            managerPhone: '+1-809-555-0401',
          ),
          BranchModel(
            id: 'branch_nacional_2',
            name: 'Nacional Bella Vista',
            address: AddressModel(
              street: 'Av. Sarasota No. 20',
              city: 'Santo Domingo',
              state: 'Distrito Nacional',
              country: 'República Dominicana',
              zipCode: '10205',
            ),
            managerName: 'Patricia Morales',
            managerPhone: '+1-809-555-0402',
          ),
        ],
        contacts: [
          ContactModel(
            id: 'contact_nacional_1',
            name: 'Francisco Herrera',
            email: 'francisco.herrera@nacional.com.do',
            phone: '+1-809-555-0411',
            position: 'Jefe de Mantenimiento',
            type: ContactType.technical,
            isPrimary: true,
          ),
        ],
        notes:
            'Cadena de supermercados. Sistemas de refrigeración y climatización críticos.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
      ),
      ClientModel(
        id: '',
        name: 'Consultorio Dr. Ramírez',
        email: 'consultorio@drramirez.com',
        phone: '+1-809-555-5555',
        taxId: '401-44444-4',
        type: ClientType.small,
        status: ClientStatus.active,
        mainAddress: AddressModel(
          street: 'Av. Independencia No. 408',
          city: 'Santo Domingo',
          state: 'Distrito Nacional',
          country: 'República Dominicana',
          zipCode: '10202',
        ),
        branches: [],
        contacts: [
          ContactModel(
            id: 'contact_doctor_1',
            name: 'Dr. José Ramírez',
            email: 'jose.ramirez@drramirez.com',
            phone: '+1-809-555-5555',
            position: 'Médico Director',
            type: ContactType.management,
            isPrimary: true,
          ),
        ],
        notes: 'Consultorio médico pequeño. Mantenimiento semestral.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: createdBy,
      ),
    ];

    // Crear cada cliente
    for (var client in mockClients) {
      try {
        await createClient(client);
        print('Cliente creado: ${client.name}');
      } catch (e) {
        print('Error creando cliente ${client.name}: $e');
      }
    }
  }
}
