import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/api/api_client.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/services/member_plan_service.dart';

class MemberOnboardingPage extends StatefulWidget {
  const MemberOnboardingPage({super.key});

  @override
  State<MemberOnboardingPage> createState() => _MemberOnboardingPageState();
}

class _MemberOnboardingPageState extends State<MemberOnboardingPage> {
  int _screen = 0; // 0=stats, 1=goals, 2=success
  bool _loading = false;
  String? _error;

  // Screen 1 state
  String? _sex; // 'male' or 'female'
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  // Screen 2 state
  String _goal = 'lose_fat';
  String _fitnessLevel = 'beginner';
  int _daysPerWeek = 4;
  String _dietPref = 'none';
  final _limitationsCtrl = TextEditingController();

  // Success state
  String _planSummary = '';

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _limitationsCtrl.dispose();
    super.dispose();
  }

  bool _validateScreen1() {
    if (_sex == null) return false;
    if (_ageCtrl.text.trim().isEmpty) return false;
    if (_weightCtrl.text.trim().isEmpty) return false;
    if (_heightCtrl.text.trim().isEmpty) return false;
    final age = int.tryParse(_ageCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = int.tryParse(_heightCtrl.text.trim());
    return age != null && weight != null && height != null;
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token!;
      final result = await MemberPlanService.saveProfile(token, {
        'sex': _sex,
        'age': int.parse(_ageCtrl.text.trim()),
        'weightKg': double.parse(_weightCtrl.text.trim()),
        'heightCm': int.parse(_heightCtrl.text.trim()),
        'goal': _goal,
        'fitnessLevel': _fitnessLevel,
        'daysPerWeek': _daysPerWeek,
        'dietPref': _dietPref,
        'limitations': _limitationsCtrl.text.trim(),
      });
      // Build summary string
      final wp = result['workoutPlan'];
      final mp = result['mealPlan'];
      final kcal = mp?['dailyCalories'] ?? '';
      _planSummary =
          '${wp?["name"] ?? "Plan"} · $_daysPerWeek days/week · $kcal kcal';
      setState(() {
        _loading = false;
        _screen = 2;
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Widget _chip(
    String label,
    String value,
    String current,
    VoidCallback onTap,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1d1d1f) : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF1d1d1f)
                : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF1d1d1f),
          ),
        ),
      ),
    );
  }

  Widget _daysChip(int days) {
    final selected = _daysPerWeek == days;
    return GestureDetector(
      onTap: () => setState(() => _daysPerWeek = days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1d1d1f) : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF1d1d1f)
                : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$days days',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF1d1d1f),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Let's personalise your plan.",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1d1d1f),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'A few quick details.',
          style: TextStyle(fontSize: 15, color: Color(0xFF6E6E73)),
        ),
        const SizedBox(height: 28),
        const Text(
          'Sex',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1d1d1f),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _chip('Male', 'male', _sex ?? '', () => setState(() => _sex = 'male')),
            const SizedBox(width: 10),
            _chip(
              'Female',
              'female',
              _sex ?? '',
              () => setState(() => _sex = 'female'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age',
            suffixText: 'yrs',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight',
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _heightCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Height',
            suffixText: 'cm',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _validateScreen1()
                ? () => setState(() => _screen = 1)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _validateScreen1()
                    ? const Color(0xFF1d1d1f)
                    : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Continue →',
                  style: TextStyle(
                    color: _validateScreen1()
                        ? Colors.white
                        : const Color(0xFF6E6E73),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1d1d1f),
      ),
    ),
  );

  Widget _buildScreen2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "What's your goal?",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1d1d1f),
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel('Goal'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(
              'Lose Fat',
              'lose_fat',
              _goal,
              () => setState(() => _goal = 'lose_fat'),
            ),
            _chip(
              'Build Muscle',
              'build_muscle',
              _goal,
              () => setState(() => _goal = 'build_muscle'),
            ),
            _chip(
              'Get Fit',
              'get_fit',
              _goal,
              () => setState(() => _goal = 'get_fit'),
            ),
            _chip(
              'Maintain',
              'maintain',
              _goal,
              () => setState(() => _goal = 'maintain'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Fitness Level'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(
              'Beginner',
              'beginner',
              _fitnessLevel,
              () => setState(() => _fitnessLevel = 'beginner'),
            ),
            _chip(
              'Intermediate',
              'intermediate',
              _fitnessLevel,
              () => setState(() => _fitnessLevel = 'intermediate'),
            ),
            _chip(
              'Advanced',
              'advanced',
              _fitnessLevel,
              () => setState(() => _fitnessLevel = 'advanced'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionLabel('Days per week'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [3, 4, 5, 6].map(_daysChip).toList(),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Diet preference'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(
              'No Restriction',
              'none',
              _dietPref,
              () => setState(() => _dietPref = 'none'),
            ),
            _chip(
              'Vegetarian',
              'vegetarian',
              _dietPref,
              () => setState(() => _dietPref = 'vegetarian'),
            ),
            _chip(
              'Vegan',
              'vegan',
              _dietPref,
              () => setState(() => _dietPref = 'vegan'),
            ),
            _chip(
              'Keto',
              'keto',
              _dietPref,
              () => setState(() => _dietPref = 'keto'),
            ),
            _chip(
              'High-Protein',
              'high_protein',
              _dietPref,
              () => setState(() => _dietPref = 'high_protein'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _limitationsCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Injuries or limitations (optional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _loading ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1d1d1f),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Build My Plan →',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreen3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Color(0xFF1d1d1f),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your plan is ready.',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1d1d1f),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _planSummary,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6E6E73)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1d1d1f),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'View My Plan →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _screen > 0 && _screen < 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1d1d1f)),
                onPressed: () => setState(() {
                  _screen--;
                  _error = null;
                }),
              )
            : _screen == 0
            ? IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF1d1d1f)),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey<int>(_screen),
            child: _screen == 0
                ? _buildScreen1()
                : _screen == 1
                ? _buildScreen2()
                : _buildScreen3(),
          ),
        ),
      ),
    );
  }
}
