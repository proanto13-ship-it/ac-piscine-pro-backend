import 'package:flutter/material.dart';

class UserGuidePage extends StatelessWidget {
  const UserGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide'),
        backgroundColor: const Color(0xFF0F6E7C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HelpHeroCard(),
          SizedBox(height: 12),
          _SectionTitle('Demarrage rapide'),
          SizedBox(height: 8),
          _QuickStartCard(),
          SizedBox(height: 12),
          _SectionTitle('Guide complet'),
          SizedBox(height: 8),
          _GuideAccordionCard(),
          SizedBox(height: 12),
          _SectionTitle('Questions frequentes'),
          SizedBox(height: 8),
          _FaqCard(),
          SizedBox(height: 12),
          _SectionTitle('Bonnes pratiques'),
          SizedBox(height: 8),
          _BestPracticesCard(),
          SizedBox(height: 12),
          _SectionTitle('Important'),
          SizedBox(height: 8),
          _HelpNoteCard(),
        ],
      ),
    );
  }
}

class _HelpHeroCard extends StatelessWidget {
  const _HelpHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HydrAzur Pro',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF153B5C),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Le centre d’aide terrain pour utiliser l’application avec fluidite, rigueur et confort au quotidien.',
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: Color(0xFF475467),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF153B5C),
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        '1',
        'Configurer l’entreprise',
        'Renseignez vos coordonnees, le technicien par defaut et vos tarifs internes.'
      ),
      (
        '2',
        'Ajouter un client',
        'Creez la fiche bassin avec volume, traitement, filtration, frequence de suivi et notes utiles.'
      ),
      (
        '3',
        'Faire une analyse',
        'Saisissez les mesures d’eau puis laissez l’application ouvrir le diagnostic technique.'
      ),
      (
        '4',
        'Intervenir et documenter',
        'Ajoutez un bon d’intervention, des photos, une signature et, si besoin, un devis ou une facture.'
      ),
    ];

    return _WhiteCard(
      child: Column(
        children: [
          for (final step in steps) ...[
            _StepTile(
              number: step.$1,
              title: step.$2,
              body: step.$3,
            ),
            if (step != steps.last) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _GuideAccordionCard extends StatelessWidget {
  const _GuideAccordionCard();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: const [
          _GuideExpansionTile(
            icon: Icons.groups_outlined,
            title: 'Clients et fiches bassin',
            bullets: [
              'Chaque fiche client peut contenir le nom, telephone, email, adresse, volume, traitement, type de bassin, revetement, filtration, equipements et notes.',
              'Depuis la fiche client, vous pouvez lancer une nouvelle analyse, consulter l’historique, ouvrir les interventions et gerer les documents.',
              'La fiche client sert aussi de point d’entree pour la galerie photo et le pilotage du suivi.',
            ],
          ),
          Divider(height: 1),
          _GuideExpansionTile(
            icon: Icons.science_outlined,
            title: 'Analyses et diagnostic technique',
            bullets: [
              'Saisissez pH, chlore, TAC, TH, stabilisant, temperature et observation.',
              'Le diagnostic technique synthétise les mesures, l’urgence, le plan d’intervention, les produits recommandes et le chiffrage.',
              'Le moteur prend en compte le LSI, l’equilibre chimique et le contexte du bassin pour produire une lecture utile sur le terrain.',
            ],
          ),
          Divider(height: 1),
          _GuideExpansionTile(
            icon: Icons.camera_alt_outlined,
            title: 'Diagnostic photo',
            bullets: [
              'Le diagnostic photo est particulierement utile en cas de suspicion d’algues moutardes.',
              'Pour une lecture vraiment sure, l’application attend 3 photos exploitables : ensemble, rapprochee et apres brossage.',
              'La qualite des photos est verifiee automatiquement : luminosite, contraste, nettete et definition minimale.',
              'Si la preuve photo est trop faible, la confiance baisse automatiquement et la lecture doit etre interpretee avec prudence.',
            ],
          ),
          Divider(height: 1),
          _GuideExpansionTile(
            icon: Icons.assignment_outlined,
            title: 'Interventions, photos et signatures',
            bullets: [
              'Depuis un diagnostic, vous pouvez creer un bon d’intervention avec technicien, resume, recommandations et remarques d’acces.',
              'Le bon d’intervention peut etre signe sur l’appareil et enregistre dans l’historique du client.',
              'Les photos ajoutees a l’intervention alimentent la galerie du client et peuvent servir de preuve avant / apres.',
            ],
          ),
          Divider(height: 1),
          _GuideExpansionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Devis, factures et PDF',
            bullets: [
              'L’application permet de creer des devis et des factures avec numerotation metier, TVA, acompte et reste a payer.',
              'Les statuts disponibles aident au suivi commercial : brouillon, envoye, accepte ou paye selon le document.',
              'Un devis peut etre converti en facture depuis l’historique des documents du client.',
              'Les PDF reprennent les informations de l’entreprise, du client et du document pour rester exploitables devant le client.',
            ],
          ),
          Divider(height: 1),
          _GuideExpansionTile(
            icon: Icons.cloud_sync_outlined,
            title: 'Sauvegarde et synchro',
            bullets: [
              'Les sauvegardes locales permettent de créer une copie de vos données et de restaurer un état précédent de l’application.',
              'La synchronisation cloud permet d’envoyer et de récupérer vos données entre vos appareils.',
              'Il est conseillé de créer une sauvegarde locale avant une restauration, un changement d’appareil ou une mise à jour importante.',
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard();

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: const [
          _FaqTile(
            question: 'Par quoi commencer quand j’ouvre l’application ?',
            answer:
                'Commencez par renseigner les reglages entreprise, puis ajoutez vos clients. Ensuite, utilisez le Planning pour voir les priorites du jour et ouvrez les fiches bassin.',
          ),
          Divider(height: 1),
          _FaqTile(
            question: 'Ou se trouvent les photos ?',
            answer:
                'Les photos sont principalement rattachees aux interventions. Elles restent ensuite visibles dans l’historique des interventions et dans la galerie du client.',
          ),
          Divider(height: 1),
          _FaqTile(
            question: 'Comment faire un devis ou une facture ?',
            answer:
                'Depuis un diagnostic ou depuis la fiche client, ouvrez la zone Documents. Vous pouvez creer un devis, le previsualiser, puis le convertir en facture si besoin.',
          ),
          Divider(height: 1),
          _FaqTile(
            question: 'A quoi sert le diagnostic photo ?',
            answer:
                'Il aide a conforter une suspicion visuelle, notamment pour les algues moutardes. Il ne remplace pas le jugement terrain ni des mesures de qualite.',
          ),
          Divider(height: 1),
          _FaqTile(
            question: 'Comment securiser mes donnees ?',
            answer:
                'Utilisez régulièrement les sauvegardes locales. Vous pouvez aussi activer la synchronisation cloud pour retrouver vos données sur vos autres appareils.',
          ),
        ],
      ),
    );
  }
}

class _BestPracticesCard extends StatelessWidget {
  const _BestPracticesCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      'Remplissez les fiches client le plus completement possible.',
      'Verifiez vos mesures avant de valider une analyse.',
      'Pour un doute visuel, prenez 3 photos exploitables plutot qu’une seule photo moyenne.',
      'Pensez a documenter les cas sensibles avec intervention, photos et signature.',
      'Creez des sauvegardes locales regulierement, surtout avant une restauration ou un changement d’appareil.',
      'Commencez la journee par le Planning pour repérer rapidement urgences et suivis en retard.',
    ];

    return _WhiteCard(
      child: Column(
        children: [
          for (final item in items) ...[
            _BulletLine(item),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HelpNoteCard extends StatelessWidget {
  const _HelpNoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB2DDFF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF175CD3)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Le diagnostic technique et le diagnostic photo sont des aides metier. Ils doivent toujours etre relus avec votre jugement terrain, surtout si les mesures ou les photos sont incompletes ou de qualite insuffisante.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF1849A9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _WhiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: child,
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _StepTile({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F6E7C),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF153B5C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF475467),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideExpansionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> bullets;

  const _GuideExpansionTile({
    required this.icon,
    required this.title,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF0F6E7C)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF153B5C),
          ),
        ),
        children: bullets.map((item) => _BulletLine(item)).toList(),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF153B5C),
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF475467),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 7,
              color: Color(0xFF0F6E7C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF344054),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
