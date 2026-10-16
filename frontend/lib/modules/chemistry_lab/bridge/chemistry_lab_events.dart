sealed class ChemistryLabEvent {
  const ChemistryLabEvent();
}

class ChemistryLabReadyEvent extends ChemistryLabEvent {
  const ChemistryLabReadyEvent();
}

class ChemistryLabSelectionEvent extends ChemistryLabEvent {
  final String? id;
  final String? name;

  const ChemistryLabSelectionEvent({this.id, this.name});
}

class ChemistryLabStopcockEvent extends ChemistryLabEvent {
  final bool open;
  const ChemistryLabStopcockEvent(this.open);
}

class ChemistryLabErrorEvent extends ChemistryLabEvent {
  final String message;
  const ChemistryLabErrorEvent(this.message);
}
