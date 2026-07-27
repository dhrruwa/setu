import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../risk/risk_engine.dart';
import '../theme/tokens.dart';
import '../widgets/asha_scaffold.dart';
import '../widgets/big_action_button.dart';
import '../widgets/risk_chip.dart';
import '../widgets/setu_card.dart';

class RegisterMotherScreen extends ConsumerStatefulWidget {
  const RegisterMotherScreen({super.key});

  @override
  ConsumerState<RegisterMotherScreen> createState() =>
      _RegisterMotherScreenState();
}

class _RegisterMotherScreenState extends ConsumerState<RegisterMotherScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _husband = TextEditingController();
  final _phone = TextEditingController();
  final _village = TextEditingController();
  final _subCentre = TextEditingController(text: 'ಹೊಸಳ್ಳಿ ಉಪ ಕೇಂದ್ರ');
  final _abha = TextEditingController();
  final _gravida = TextEditingController(text: '1');
  final _para = TextEditingController(text: '0');
  final _height = TextEditingController();

  DateTime? _lmp;
  String? _bloodGroup;
  bool _isBpl = false;
  final Set<String> _complications = {};
  bool _scanning = false;
  bool _fromScan = false;
  bool _saving = false;

  static const _complicationIds = [
    'cSection',
    'stillbirth',
    'pph',
    'hypertension',
    'gdm',
    'anaemia',
  ];

  @override
  void dispose() {
    for (final c in [
      _name,
      _age,
      _husband,
      _phone,
      _village,
      _subCentre,
      _abha,
      _gravida,
      _para,
      _height,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// OCR output is never saved silently — it prefills the same editable form
  /// so she confirms every field.
  Future<void> _scan() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _scanning = true);
    final result = await ref.read(ocrServiceProvider).readThayiCard(picked.path);
    if (!mounted) return;

    setState(() {
      _scanning = false;
      _fromScan = true;
      _name.text = result.name ?? '';
      _age.text = result.age?.toString() ?? '';
      _husband.text = result.husbandName ?? '';
      _phone.text = result.phone ?? '';
      _village.text = result.village ?? '';
      _subCentre.text = result.subCentre ?? _subCentre.text;
      _abha.text = result.abhaId ?? '';
      _gravida.text = result.gravida?.toString() ?? '1';
      _para.text = result.para?.toString() ?? '0';
      _height.text = result.heightCm?.toStringAsFixed(0) ?? '';
      _bloodGroup = result.bloodGroup;
      _lmp = result.lmp;
    });
  }

  Future<void> _pickLmp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lmp ?? now.subtract(const Duration(days: 90)),
      firstDate: now.subtract(const Duration(days: 300)),
      lastDate: now,
    );
    if (picked != null) setState(() => _lmp = picked);
  }

  Future<void> _save(AppLocalizations l) async {
    final name = _name.text.trim();
    final age = int.tryParse(_age.text);
    final village = _village.text.trim();

    if (name.isEmpty || age == null || village.isEmpty || _lmp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.requiredField, style: T.body)),
      );
      return;
    }

    setState(() => _saving = true);

    final engine = ref.read(riskEngineProvider).valueOrNull;
    final profile = RiskProfile(
      age: age,
      gravida: int.tryParse(_gravida.text) ?? 1,
      prevComplications: _complications.toList(),
      lmp: _lmp!,
    );
    // R6 runs at registration, so a high-risk pregnancy is flagged before she
    // ever leaves the doorway.
    final alerts = engine?.evaluateProfile(profile) ?? const <RiskAlert>[];

    final repo = ref.read(visitRepositoryProvider);
    final id = await repo.registerMother(
      name: name,
      age: age,
      village: village,
      lmp: _lmp!,
      husbandName: _husband.text.trim().isEmpty ? null : _husband.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      subCentre: _subCentre.text.trim(),
      abhaId: _abha.text.trim().isEmpty ? null : _abha.text.trim(),
      gravida: int.tryParse(_gravida.text) ?? 1,
      para: int.tryParse(_para.text) ?? 0,
      bloodGroup: _bloodGroup,
      heightCm: double.tryParse(_height.text),
      isBpl: _isBpl,
      prevComplications: _complications.toList(),
      riskLevel: RiskEngine.levelOf(alerts),
    );
    await repo.saveAlerts(id, null, alerts);

    if (!mounted) return;
    setState(() => _saving = false);
    await _showResult(l, name, alerts);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showResult(
    AppLocalizations l,
    String name,
    List<RiskAlert> alerts,
  ) {
    final isKn = l.localeName.startsWith('kn');
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(S.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.screen, 0, S.screen, S.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: C.green, size: 30),
                  const SizedBox(width: S.sm),
                  Expanded(child: Text(l.motherSaved(name), style: T.h2)),
                ],
              ),
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: S.md),
                for (final a in alerts)
                  Container(
                    margin: const EdgeInsets.only(bottom: S.sm),
                    padding: const EdgeInsets.all(S.md),
                    decoration: BoxDecoration(
                      color: a.isRed ? C.redSoft : C.amberSoft,
                      borderRadius: BorderRadius.circular(S.radius),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 24, color: a.isRed ? C.red : C.amber),
                        const SizedBox(width: S.sm),
                        Expanded(
                          child: Text(
                            isKn ? a.messageKn : a.messageEn,
                            style: T.body,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: S.md),
              SectionHeader(l.schemesQualified),
              Wrap(
                spacing: S.sm,
                runSpacing: S.sm,
                children: [
                  if (_isBpl) ...[
                    RiskChip(
                        label: l.schemeThayiBhagya, level: RiskLevel.normal),
                    RiskChip(label: l.schemeJsy, level: RiskLevel.normal),
                    RiskChip(label: l.schemeMadilu, level: RiskLevel.normal),
                  ],
                  if ((int.tryParse(_para.text) ?? 0) == 0)
                    RiskChip(label: l.schemePmmvy, level: RiskLevel.normal),
                  RiskChip(label: l.schemeJssk, level: RiskLevel.normal),
                ],
              ),
              const SizedBox(height: S.md),
              Text(l.schemesNote, style: T.label),
              const SizedBox(height: S.md),
              BigActionButton(
                label: l.ok,
                icon: Icons.check,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return AshaScaffold(
      title: l.registerTitle,
      body: ListView(
        padding: const EdgeInsets.all(S.screen),
        children: [
          Row(
            children: [
              Expanded(
                child: _PathCard(
                  icon: Icons.document_scanner_outlined,
                  title: l.scanThayiCard,
                  subtitle: l.scanHint,
                  accent: C.terra,
                  busy: _scanning,
                  onTap: _scanning ? null : _scan,
                ),
              ),
              const SizedBox(width: S.md),
              Expanded(
                child: _PathCard(
                  icon: Icons.edit_outlined,
                  title: l.manualEntry,
                  subtitle: '',
                  accent: C.teal,
                  onTap: () => setState(() => _fromScan = false),
                ),
              ),
            ],
          ),
          if (_fromScan) ...[
            const SizedBox(height: S.md),
            Container(
              padding: const EdgeInsets.all(S.md),
              decoration: BoxDecoration(
                color: C.amberSoft,
                borderRadius: BorderRadius.circular(S.radius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.fact_check_outlined,
                      size: 24, color: C.amber),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text(l.confirmEachField, style: T.body),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: S.lg),
          SetuCard(
            padding: const EdgeInsets.all(S.md),
            child: Column(
              children: [
                _Field(controller: _name, label: l.fieldName),
                _Field(
                  controller: _age,
                  label: l.fieldAge,
                  number: true,
                  maxLength: 2,
                ),
                _Field(controller: _husband, label: l.fieldHusband),
                _Field(
                  controller: _phone,
                  label: l.fieldPhone,
                  number: true,
                  maxLength: 10,
                ),
                _Field(controller: _village, label: l.fieldVillage),
                _Field(controller: _subCentre, label: l.fieldSubCentre),
                _Field(controller: _abha, label: '${l.fieldAbha} (${l.optional})'),
              ],
            ),
          ),
          const SizedBox(height: S.md),
          SetuCard(
            padding: const EdgeInsets.all(S.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.fieldLmp, style: T.label),
                const SizedBox(height: S.sm),
                OutlinedButton.icon(
                  onPressed: _pickLmp,
                  icon: const Icon(Icons.calendar_today_outlined, size: 24),
                  label: Text(
                    _lmp == null
                        ? l.pickDate
                        : DateFormat('d MMM yyyy', l.localeName).format(_lmp!),
                  ),
                ),
                if (_lmp != null) ...[
                  const SizedBox(height: S.md),
                  // Live, so she can sanity-check the date she just entered.
                  Container(
                    padding: const EdgeInsets.all(S.md),
                    decoration: BoxDecoration(
                      color: C.tealSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.gaComputed(
                            gestationWeeks(_lmp!),
                            gestationDays(_lmp!),
                          ),
                          style: T.h2.copyWith(color: C.teal),
                        ),
                        const SizedBox(height: S.xs),
                        Text(
                          l.eddComputed(
                            DateFormat('d MMM yyyy', l.localeName)
                                .format(eddOf(_lmp!)),
                          ),
                          style: T.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: S.md),
          SetuCard(
            padding: const EdgeInsets.all(S.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _gravida,
                        label: l.fieldGravida,
                        number: true,
                        maxLength: 2,
                      ),
                    ),
                    const SizedBox(width: S.md),
                    Expanded(
                      child: _Field(
                        controller: _para,
                        label: l.fieldPara,
                        number: true,
                        maxLength: 2,
                      ),
                    ),
                  ],
                ),
                _Field(
                  controller: _height,
                  label: l.fieldHeight,
                  number: true,
                  maxLength: 3,
                ),
                const SizedBox(height: S.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.fieldBloodGroup, style: T.label),
                ),
                const SizedBox(height: S.sm),
                Wrap(
                  spacing: S.sm,
                  children: [
                    for (final bg in [
                      'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'
                    ])
                      ChoiceChip(
                        label: Text(bg, style: T.body),
                        selected: _bloodGroup == bg,
                        selectedColor: C.tealSoft,
                        onSelected: (_) => setState(() => _bloodGroup = bg),
                      ),
                  ],
                ),
                const SizedBox(height: S.sm),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isBpl,
                  onChanged: (v) => setState(() => _isBpl = v),
                  activeThumbColor: C.teal,
                  title: Text(l.fieldBpl, style: T.body),
                ),
              ],
            ),
          ),
          const SizedBox(height: S.md),
          SectionHeader(l.prevComplications),
          SetuCard(
            padding: const EdgeInsets.all(S.md),
            child: Wrap(
              spacing: S.sm,
              runSpacing: S.sm,
              children: [
                for (final id in _complicationIds)
                  FilterChip(
                    label: Text(_complicationLabel(l, id), style: T.body),
                    selected: _complications.contains(id),
                    selectedColor: C.amberSoft,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _complications.add(id);
                      } else {
                        _complications.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: S.lg),
          BigActionButton(
            label: l.saveMother,
            icon: Icons.person_add_alt,
            onPressed: _saving ? null : () => _save(l),
          ),
          const SizedBox(height: S.xl),
        ],
      ),
    );
  }

  String _complicationLabel(AppLocalizations l, String id) => switch (id) {
        'cSection' => l.compCSection,
        'stillbirth' => l.compStillbirth,
        'pph' => l.compPph,
        'hypertension' => l.compHypertension,
        'gdm' => l.compGdm,
        _ => l.compAnaemia,
      };
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SetuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(S.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3, color: C.terra),
            )
          else
            Icon(icon, size: 34, color: accent),
          const SizedBox(height: S.sm),
          Text(
            busy ? l.scanning : title,
            style: T.body.copyWith(fontWeight: FontWeight.w600),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: S.xs),
            Text(subtitle, style: T.label.copyWith(fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.number = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final bool number;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.md),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLength: maxLength,
        style: T.body,
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(labelText: label, counterText: ''),
      ),
    );
  }
}
