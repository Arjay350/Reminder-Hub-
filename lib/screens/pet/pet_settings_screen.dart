import 'package:flutter/material.dart';
import '../../models/pet_models.dart';
import '../../services/pet_audio_service.dart';
import '../../services/pet_service.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/pet/pet_widget.dart';
import '../../widgets/pet/pet_mood_badge.dart';

class PetSettingsScreen extends StatefulWidget {
  const PetSettingsScreen({super.key});

  @override
  State<PetSettingsScreen> createState() => _PetSettingsScreenState();
}

class _PetSettingsScreenState extends State<PetSettingsScreen> {
  final PetService _service = PetService.instance;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _service.preferences.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateCoat(PetCoatStyle style) async {
    await _service.updatePreferences(
      _service.preferences.copyWith(coatStyle: style),
    );
    setState(() {});
  }

  Future<void> _toggleEnabled(bool val) async {
    await _service.updatePreferences(
      _service.preferences.copyWith(enabled: val),
    );
    setState(() {});
  }

  Future<void> _toggleReactions(bool val) async {
    await _service.updatePreferences(
      _service.preferences.copyWith(interactionReactionsEnabled: val),
    );
    setState(() {});
  }

  Future<void> _toggleMovement(bool val) async {
    await _service.updatePreferences(
      _service.preferences.copyWith(movementEnabled: val),
    );
    setState(() {});
  }

  Future<void> _toggleSound(bool val) async {
    await _service.updatePreferences(
      _service.preferences.copyWith(soundEnabled: val),
    );
    if (val) {
      PetAudioService.instance.playMeow();
    }
    setState(() {});
  }

  Future<void> _editName() async {
    _nameController.text = _service.preferences.name;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF141A2E) : Colors.white,
        title: const Text('Name Your Pet'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Pet Name',
            hintText: 'e.g. Mochi, Luna, Whiskers',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            prefixIcon: const Icon(Icons.pets),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                await _service.updatePreferences(
                  _service.preferences.copyWith(name: newName),
                );
                setState(() {});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prefs = _service.preferences;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pet Companion Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Pet Preview Hero Card
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            child: Column(
              children: [
                Center(
                  child: PetWidget(
                    width: 140,
                    height: 125,
                    showSpeechBubble: true,
                    allowInteractions: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      prefs.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Change Pet Name',
                      onPressed: _editName,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Level ${prefs.petLevel} • ${prefs.growthStage.displayName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PetMoodLiveBadge(service: _service),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restaurant_rounded,
                      size: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Hunger: ${prefs.hunger.round()}% (${prefs.hungerState.displayName})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.health_and_safety_rounded,
                      size: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Body Condition: ${prefs.bodyCondition.displayName} (${prefs.bodyConditionScore.round()}/100)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // General Settings
          _sectionHeader('General'),
          CustomCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: prefs.enabled,
                  onChanged: _toggleEnabled,
                  title: const Text(
                    'Enable Pet Companion',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Display your pet companion on the dashboard'),
                  secondary: _iconContainer(Icons.pets, const Color(0xFF6366F1)),
                ),
                const Divider(height: 1, indent: 64),
                SwitchListTile.adaptive(
                  value: prefs.interactionReactionsEnabled,
                  onChanged: prefs.enabled ? _toggleReactions : null,
                  title: const Text(
                    'Event Reactions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Celebrate reminders, bills, classes & focus'),
                  secondary: _iconContainer(Icons.celebration, const Color(0xFF10B981)),
                ),
                const Divider(height: 1, indent: 64),
                SwitchListTile.adaptive(
                  value: prefs.movementEnabled,
                  onChanged: prefs.enabled ? _toggleMovement : null,
                  title: const Text(
                    'Idle Movement',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Allow pet to stroll gently inside dashboard card'),
                  secondary: _iconContainer(Icons.directions_walk, const Color(0xFFF59E0B)),
                ),
                const Divider(height: 1, indent: 64),
                SwitchListTile.adaptive(
                  value: prefs.soundEnabled,
                  onChanged: prefs.enabled ? _toggleSound : null,
                  title: const Text(
                    'Sound Effects',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Audio purrs & meows when tapped or petted'),
                  secondary: _iconContainer(Icons.volume_up, const Color(0xFF8B5CF6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Coat & Appearance
          _sectionHeader('Appearance & Coat Style'),
          CustomCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _coatOption(
                          title: 'Ginger Tabby',
                          subtitle: 'Warm orange stripes',
                          style: PetCoatStyle.gingerTabby,
                          color: const Color(0xFFF59E0B),
                          isSelected: prefs.coatStyle == PetCoatStyle.gingerTabby,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _coatOption(
                          title: 'Midnight Tuxedo',
                          subtitle: 'Charcoal & white socks',
                          style: PetCoatStyle.tuxedoMidnight,
                          color: const Color(0xFF1E293B),
                          isSelected: prefs.coatStyle == PetCoatStyle.tuxedoMidnight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _coatOption(
                          title: 'Calico Patch',
                          subtitle: 'Tricolor ginger & dark',
                          style: PetCoatStyle.calico,
                          color: const Color(0xFFEA580C),
                          isSelected: prefs.coatStyle == PetCoatStyle.calico,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _coatOption(
                          title: 'Snow White',
                          subtitle: 'Pure ivory & soft pink',
                          style: PetCoatStyle.snowWhite,
                          color: const Color(0xFF94A3B8),
                          isSelected: prefs.coatStyle == PetCoatStyle.snowWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Companion Progression & Bond Statistics
          _sectionHeader('Companion Progression & Statistics'),
          CustomCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _statRow(
                  icon: Icons.trending_up,
                  color: const Color(0xFF6366F1),
                  label: 'Current Level & Stage',
                  value: 'Lv. ${prefs.petLevel} (${prefs.growthStage.displayName})',
                ),
                const Divider(height: 20),
                _statRow(
                  icon: Icons.stars,
                  color: const Color(0xFFF59E0B),
                  label: 'Total XP Earned',
                  value: '${prefs.totalXp} XP',
                ),
                const Divider(height: 20),
                _statRow(
                  icon: Icons.restaurant,
                  color: const Color(0xFF10B981),
                  label: 'Total Meals Fed',
                  value: '${prefs.totalFeedings}',
                ),
                const Divider(height: 20),
                _statRow(
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFFD97706),
                  label: 'Food in Inventory',
                  value: '${prefs.foodInventory}',
                ),
                const Divider(height: 20),
                _statRow(
                  icon: Icons.favorite,
                  color: const Color(0xFFF43F5E),
                  label: 'Times Petted',
                  value: '${prefs.totalPets}',
                ),
                const Divider(height: 20),
                _statRow(
                  icon: Icons.touch_app,
                  color: const Color(0xFF6366F1),
                  label: 'Total Interactions',
                  value: '${prefs.totalInteractions}',
                ),
                const Divider(height: 20),
                _statRow(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                  label: 'Tasks Celebrated',
                  value: '${prefs.tasksCelebrated}',
                ),
                const Divider(height: 20),
                _statRow(
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: 'Focus Sessions Shared',
                  value: '${prefs.studySessionsAccompanied}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _coatOption({
    required String title,
    required String subtitle,
    required PetCoatStyle style,
    required Color color,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _updateCoat(style),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white70 : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _iconContainer(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
