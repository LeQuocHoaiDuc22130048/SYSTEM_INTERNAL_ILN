import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/models/customer.dart';

void main() {
  group('Customer Model Tests', () {
    test('Customer.fromJson correctly parses individual customer', () {
      final json = {
        'id': 'c8e4fc57-f9ef-4bf8-96f7-c6b3fc5d9b73',
        'customerCode': 'KH-1234567890abcdef1234567890abcdef',
        'customerName': 'Nguyễn Văn A',
        'type': 'INDIVIDUAL',
        'phone': '0901234567',
        'email': 'vana@gmail.com',
        'address': '123 Đường Số 1, TP. HCM',
        'taxCode': null,
        'notes': 'Khách quen',
        'active': true,
        'createdAt': '2026-10-14T08:00:00Z',
        'updatedAt': '2026-10-14T08:30:00Z',
      };

      final customer = Customer.fromJson(json);

      expect(customer.id, 'c8e4fc57-f9ef-4bf8-96f7-c6b3fc5d9b73');
      expect(customer.customerCode, 'KH-1234567890abcdef1234567890abcdef');
      expect(customer.customerName, 'Nguyễn Văn A');
      expect(customer.name, 'Nguyễn Văn A');
      expect(customer.type, CustomerType.individual);
      expect(customer.typeLabel, 'Cá nhân');
      expect(customer.isCompany, isFalse);
      expect(customer.isIndividual, isTrue);
      expect(customer.phone, '0901234567');
      expect(customer.email, 'vana@gmail.com');
      expect(customer.address, '123 Đường Số 1, TP. HCM');
      expect(customer.taxCode, isNull);
      expect(customer.notes, 'Khách quen');
      expect(customer.active, isTrue);
      expect(customer.createdAt, isNotNull);
      expect(customer.updatedAt, isNotNull);
    });

    test('Customer.fromJson correctly parses company customer', () {
      final json = {
        'id': 'b1e4fc57-f9ef-4bf8-96f7-c6b3fc5d9b74',
        'customerCode': 'KH-abcdef1234567890abcdef1234567890',
        'customerName': 'Công ty TNHH Giải Pháp Công Nghệ',
        'type': 'COMPANY',
        'phone': '0281234567',
        'email': 'contact@company.vn',
        'address': 'Tòa nhà A, Quận 1',
        'taxCode': '0312345678',
        'notes': 'Hợp đồng bảo trì inverter',
        'active': false,
      };

      final customer = Customer.fromJson(json);

      expect(customer.name, 'Công ty TNHH Giải Pháp Công Nghệ');
      expect(customer.type, CustomerType.company);
      expect(customer.typeLabel, 'Doanh nghiệp');
      expect(customer.isCompany, isTrue);
      expect(customer.isIndividual, isFalse);
      expect(customer.taxCode, '0312345678');
      expect(customer.active, isFalse);
    });

    test('toRequestJson correctly trims and prepares body', () {
      const customer = Customer(
        id: '123',
        customerCode: 'KH-123',
        customerName: '  Công ty B  ',
        type: CustomerType.company,
        phone: '  0908765432  ',
        email: '   ',
        address: '  12 Hùng Vương ',
        taxCode: '  0102030405  ',
        notes: null,
        active: true,
      );

      final req = customer.toRequestJson();
      expect(req['customerName'], 'Công ty B');
      expect(req['type'], 'COMPANY');
      expect(req['phone'], '0908765432');
      expect(req['email'], isNull); // Blank converted to null
      expect(req['address'], '12 Hùng Vương');
      expect(req['taxCode'], '0102030405');
      expect(req['notes'], isNull);
    });

    test('CustomerPage.fromJson parses page wrapper', () {
      final json = {
        'content': [
          {
            'id': 'c1',
            'customerCode': 'KH-1',
            'customerName': 'KH 1',
            'type': 'INDIVIDUAL',
            'active': true,
          },
          {
            'id': 'c2',
            'customerCode': 'KH-2',
            'customerName': 'KH 2',
            'type': 'COMPANY',
            'active': false,
          },
        ],
        'number': 0,
        'size': 20,
        'totalElements': 2,
        'totalPages': 1,
        'last': true,
      };

      final page = CustomerPage.fromJson(json);
      expect(page.content.length, 2);
      expect(page.totalElements, 2);
      expect(page.totalPages, 1);
      expect(page.number, 0);
      expect(page.last, isTrue);
    });
  });
}
