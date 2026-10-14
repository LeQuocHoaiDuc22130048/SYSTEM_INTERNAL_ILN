import 'package:flutter/material.dart';
import '../../models/user.dart';

class AddMembersDialog extends StatefulWidget {
  const AddMembersDialog({super.key, required this.employees});
  final List<User> employees;
  @override
  State<AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<AddMembersDialog> {
  final _selected = <String>{};
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final users = widget.employees
        .where(
          (user) =>
              user.name.toLowerCase().contains(_query.toLowerCase()) ||
              user.employeeId.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: const Text('Thêm thành viên'),
      content: SizedBox(
        width: 400,
        height: 340,
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Tìm nhân viên',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: users.isEmpty
                  ? const Center(child: Text('Không có nhân viên phù hợp'))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (_, index) {
                        final user = users[index];
                        return CheckboxListTile(
                          title: Text(user.name),
                          value: _selected.contains(user.id),
                          onChanged: (selected) => setState(() {
                            if (selected == true) {
                              _selected.add(user.id);
                            } else {
                              _selected.remove(user.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}
