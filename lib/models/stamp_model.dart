/// Modelo de categoría de sellos
class StampCategory {
  final String id;
  final String name;
  final String emoji;
  final List<StampItem> stamps;

  const StampCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.stamps,
  });
}

/// Un sello individual
class StampItem {
  final String id;
  final String name;
  final String assetPath;

  const StampItem({
    required this.id,
    required this.name,
    required this.assetPath,
  });
}

/// Todas las categorías y sellos disponibles
class StampLibrary {
  static const List<StampCategory> categories = [
    StampCategory(
      id: 'elementos',
      name: 'Elementos',
      emoji: '💀',
      stamps: [
        StampItem(id: 'ele_01', name: 'Tribal',       assetPath: 'assets/stamps/elementos/ele_01.png'),
        StampItem(id: 'ele_04', name: 'Luna',          assetPath: 'assets/stamps/elementos/ele_04.png'),
        StampItem(id: 'ele_05', name: 'Rayo',          assetPath: 'assets/stamps/elementos/ele_05.png'),
        StampItem(id: 'ele_06', name: 'Llama',         assetPath: 'assets/stamps/elementos/ele_06.png'),
        StampItem(id: 'ele_07', name: 'Ola',           assetPath: 'assets/stamps/elementos/ele_07.png'),
        StampItem(id: 'ele_08', name: 'Nube',          assetPath: 'assets/stamps/elementos/ele_08.png'),
        StampItem(id: 'ele_09', name: 'Cristal',       assetPath: 'assets/stamps/elementos/ele_09.png'),
        StampItem(id: 'ele_10', name: 'Calavera',      assetPath: 'assets/stamps/elementos/ele_10.png'),
        StampItem(id: 'ele_11', name: 'Rosa',          assetPath: 'assets/stamps/elementos/ele_11.png'),
        StampItem(id: 'ele_12', name: 'Serpiente',     assetPath: 'assets/stamps/elementos/ele_12.png'),
        StampItem(id: 'ele_13', name: 'Águila',        assetPath: 'assets/stamps/elementos/ele_13.png'),
        StampItem(id: 'ele_14a', name: 'Dragón 1',    assetPath: 'assets/stamps/elementos/ele_14a.png'),
        StampItem(id: 'ele_14b', name: 'Dragón 2',    assetPath: 'assets/stamps/elementos/ele_14b.png'),
        StampItem(id: 'ele_14c', name: 'Dragón 3',    assetPath: 'assets/stamps/elementos/ele_14c.png'),
        StampItem(id: 'ele_15a', name: 'Tribal 1',    assetPath: 'assets/stamps/elementos/ele_15a.png'),
        StampItem(id: 'ele_15b', name: 'Tribal 2',    assetPath: 'assets/stamps/elementos/ele_15b.png'),
      ],
    ),
    StampCategory(
      id: 'organicos',
      name: 'Orgánicos',
      emoji: '🌿',
      stamps: [
        StampItem(id: 'org_01', name: 'Coral',         assetPath: 'assets/stamps/organicos/org_01.png'),
        StampItem(id: 'org_02', name: 'Árbol Raíz',    assetPath: 'assets/stamps/organicos/org_02.png'),
        StampItem(id: 'org_03', name: 'Enredadera',    assetPath: 'assets/stamps/organicos/org_03.png'),
        StampItem(id: 'org_04', name: 'Hoja',          assetPath: 'assets/stamps/organicos/org_04.png'),
        StampItem(id: 'org_05', name: 'Espina',        assetPath: 'assets/stamps/organicos/org_05.png'),
        StampItem(id: 'org_06', name: 'Hongo 1',       assetPath: 'assets/stamps/organicos/org_06.png'),
        StampItem(id: 'org_07', name: 'Hongo 2',       assetPath: 'assets/stamps/organicos/org_07.png'),
        StampItem(id: 'org_08', name: 'Árbol',         assetPath: 'assets/stamps/organicos/org_08.png'),
        StampItem(id: 'org_09', name: 'Árbol Seco',    assetPath: 'assets/stamps/organicos/org_09.png'),
        StampItem(id: 'org_10', name: 'Huesos',        assetPath: 'assets/stamps/organicos/org_10.png'),
        StampItem(id: 'org_11', name: 'Pluma',         assetPath: 'assets/stamps/organicos/org_11.png'),
        StampItem(id: 'org_12', name: 'Concha',        assetPath: 'assets/stamps/organicos/org_12.png'),
        StampItem(id: 'org_13', name: 'Bellota',       assetPath: 'assets/stamps/organicos/org_13.png'),
        StampItem(id: 'org_14', name: 'Alga',          assetPath: 'assets/stamps/organicos/org_14.png'),
        StampItem(id: 'org_15', name: 'Rama',          assetPath: 'assets/stamps/organicos/org_15.png'),
        StampItem(id: 'org_16', name: 'Cactus',        assetPath: 'assets/stamps/organicos/org_16.png'),
      ],
    ),
    StampCategory(
      id: 'abstractos',
      name: 'Abstractos',
      emoji: '🌀',
      stamps: [
        StampItem(id: 'stamp_abs_01', name: 'Abstracto 1',  assetPath: 'assets/stamps/abstractos/stamp_abs_01.png'),
        StampItem(id: 'stamp_abs_02', name: 'Abstracto 2',  assetPath: 'assets/stamps/abstractos/stamp_abs_02.png'),
        StampItem(id: 'stamp_abs_03', name: 'Abstracto 3',  assetPath: 'assets/stamps/abstractos/stamp_abs_03.png'),
        StampItem(id: 'stamp_abs_04', name: 'Abstracto 4',  assetPath: 'assets/stamps/abstractos/stamp_abs_04.png'),
        StampItem(id: 'stamp_abs_05', name: 'Abstracto 5',  assetPath: 'assets/stamps/abstractos/stamp_abs_05.png'),
        StampItem(id: 'stamp_abs_06', name: 'Abstracto 6',  assetPath: 'assets/stamps/abstractos/stamp_abs_06.png'),
        StampItem(id: 'stamp_abs_07', name: 'Abstracto 7',  assetPath: 'assets/stamps/abstractos/stamp_abs_07.png'),
        StampItem(id: 'stamp_abs_08', name: 'Abstracto 8',  assetPath: 'assets/stamps/abstractos/stamp_abs_08.png'),
        StampItem(id: 'stamp_abs_09', name: 'Abstracto 9',  assetPath: 'assets/stamps/abstractos/stamp_abs_09.png'),
        StampItem(id: 'stamp_abs_10', name: 'Abstracto 10', assetPath: 'assets/stamps/abstractos/stamp_abs_10.png'),
        StampItem(id: 'stamp_abs_11', name: 'Abstracto 11', assetPath: 'assets/stamps/abstractos/stamp_abs_11.png'),
        StampItem(id: 'stamp_abs_12', name: 'Abstracto 12', assetPath: 'assets/stamps/abstractos/stamp_abs_12.png'),
        StampItem(id: 'stamp_abs_13', name: 'Abstracto 13', assetPath: 'assets/stamps/abstractos/stamp_abs_13.png'),
        StampItem(id: 'stamp_abs_14', name: 'Abstracto 14', assetPath: 'assets/stamps/abstractos/stamp_abs_14.png'),
      ],
    ),
    StampCategory(
      id: 'industriales',
      name: 'Industriales',
      emoji: '⚙️',
      stamps: [
        StampItem(id: 'ind_01', name: 'Engranaje 1',  assetPath: 'assets/stamps/industriales/ind_01.png'),
        StampItem(id: 'ind_02', name: 'Tornillo',     assetPath: 'assets/stamps/industriales/ind_02.png'),
        StampItem(id: 'ind_03', name: 'Engranaje 2',  assetPath: 'assets/stamps/industriales/ind_03.png'),
        StampItem(id: 'ind_04', name: 'Cadena',       assetPath: 'assets/stamps/industriales/ind_04.png'),
        StampItem(id: 'ind_05', name: 'Rayo',         assetPath: 'assets/stamps/industriales/ind_05.png'),
        StampItem(id: 'ind_06', name: 'Placa',        assetPath: 'assets/stamps/industriales/ind_06.png'),
        StampItem(id: 'ind_07', name: 'Rejilla',      assetPath: 'assets/stamps/industriales/ind_07.png'),
      ],
    ),
  ];

  /// Busca un StampItem por su id en todas las categorías
  static StampItem? findById(String id) {
    for (final cat in categories) {
      for (final stamp in cat.stamps) {
        if (stamp.id == id) return stamp;
      }
    }
    return null;
  }
}
