package AKDB::Okewo_de;
our $VERSION = "1.03";

use strict;
use Carp;
use DBI;
use DBD::Oracle;
use Date::Calc( qw(Today Days_in_Month Delta_YMD) );

use Exporter;
our @ISA=();
our @EXPORT=();
our @EXPORT_OK=();

=head1 NAME, VERSION

This module and its documentation is written in German because it deals with a software in german language.

AKDB::Okewo_de - Daten aus der Datenbank des Einwohnerwesens OK.EWO der 
Anstalt für Kommunale Datenverarbeitung in Bayern (AKDB) holen. Die kommerzielle Software OK.EWO wird in Kommunalverwaltungen eingesetzt.

=head1 KOCHBUCH

Hier sind kurze Rezepte aufgelistet um zu zeigen wie man mit dem Modul Probleme lösen kann.

Das muss immer am Anfang des Programms aufgerufen werden (evtl. ORACLE_HOME-Umgebungsvariable setzen falls kein Connect zur Datenbank möglich ist):

=head2 Immer am Anfang

	use DBI;
	use DBD::Oracle;
	use AKDB::Okewo_de;
	use Date::Calc();

	END {
		# Schließe Datenbankverbindung am Ende des Programmes
		$dbh->disconnect if $dbh;
	}

	my $config = {
		dbname => 'e01', 
		user => 'auskunft', 
		pass => 'auskunft',
		gemeindeschluessel => '09573134'
	};

	my $dbh = DBI->connect(
		$config->{dbname},
		$config->{user}, $config->{pass},
		"Oracle") 
		|| die "Konnte nicht mit $config->{dbname} connecten.\n Fehler war: $DBI::errstr";

	my $e01 = AKDB::Okewo_de->new(
		dbh=>$dbh,
		gemeindeschluessel=> $config->{gemeindeschluessel});

=head2 Gebietstypen anzeigen

Gebietstypen sind die verschiedenen Arten der Aufteilung für Ihr Gemeindegebiet (z.B. Ortsteile, Schulsprengel, Wahlbezirke...)

	&zeige_gebietstypen;

	sub zeige_gebietstypen {
		print "Gebietstypen:\n";
		foreach my $typ ( $e01->gebietstypen()) {
			printf "\t%s - %s\n",
				$typ,
				$e01->gebietstyp_klartext($typ);
		}	
	}

Ergebnis:

	Gebietstypen:
	100 - Gesamtes Stadtgebiet f³r Auswertungen
	101 - Ortsteile
	200 - Wahlbezirke
	300 - Schulbezirke
	400 - Kirchensprengel evangelisch
	401 - Kirchensprengel katholisch


=head2 Einzelne Gebietsgliederung anzeigen

Hier ein Beispiel für Ortsteile. Die Nummer 101 ist hier der Gebietstyp dafür. Er kann in Ihrer Gemeinde anders sein. Ihr Einwohneramt arbeitet ständig mit diesen Nummern und weiß deshalb darüber Bescheid.

	&zeige_gebietsgliederung(101);

	sub zeige_gebietsgliederung {
		my $gebiettyp = shift;
		
		printf "Gliederung von Gebietstyp %s (%s):\n",
			$gebiettyp,
			$e01->gebietstyp_klartext($gebiettyp);
		foreach my $gebiet_nr ( 
			$e01->gebietsgliederungen(gebiettyp=> $gebiettyp)) {
			printf "\t%s - %s\n",
				$gebiet_nr,
				$e01->gebietsgliederung_klartext(
					gebiettyp=>$gebiettyp,
					gebiet_nr=>$gebiet_nr);
		}
	}

Ergebnis:

	Gliederung von Gebietstyp 101 (Ortsteile):
	1 - Zirndorf - Kernstadt -
	2 - Weiherhof
	3 - Banderbach
	...

=head2 Einwohnerstatistik alle 

Diese Statistik zeigt die Verteilung aller Einwohner auf die Stadtteile (Gebietstyp 101 = Stadtteile).

	# zuerst e01 erzeugen mit erstem Kochrezept
	&einwohnerverteilung_nach_gebiet(101);
	

	sub einwohnerverteilung_nach_gebiet {
		my $gebiettyp = shift || die;

		my $gesamt = 0;
		printf "Verteilung der Einwohner nach %s:\n",
			$e01->gebietstyp_klartext($gebiettyp);

		# Hole eine Gliederungsliste des Gebiets
		my @gliederungen = $e01->gebietsgliederungen(gebiettyp=>$gebiettyp);

		foreach my $gliederungsnummer (@gliederungen) {
			# Wieviele Einwohner gibt es hier?
			my @ew = $e01->om_nach_gebietsgliederung(
				gebiettyp => $gebiettyp,
				gebiet_nr=> $gliederungsnummer);
			my $anz = scalar @ew;
			my $bez = $e01->gebietsgliederung_klartext(
				gebiettyp=>$gebiettyp,
				gebiet_nr=>$gliederungsnummer);
			printf "\t(%d) %s: %d Einwohner\n", $gliederungsnummer,$bez, $anz;
			$gesamt += $anz;
		}

		printf "\t->Gesamt: %d Einwohner\n", $gesamt;
	}

Ergebnis:

	Verteilung der Einwohner nach Ortsteile:
	(1) Zirndorf - Kernstadt -: 14913 Einwohner
	(2) Weiherhof: 3657 Einwohner
	(3) Banderbach: 220 Einwohner
	(4) Bronnamberg: 841 Einwohner
	(5) Weinzierlein: 1332 Einwohner
	...



=head2 Einwohnerstatistik Wahlbezirke

Diese Statistik zeigt die Verteilung aller Einwohner auf die Wahlbezirke (Gebietstyp 200 = Wahlbezirke). Hier muss man allerdings eine Alterseinschränkung vornehmen.

	# zuerst e01 erzeugen mit erstem Kochrezept
	&wahlbezirke(200, '1800-01-01', '1985-05-01');
	

	sub wahlbezirke {
		my $gebiettyp = shift || die;
		my $gebdat_von = shift || die;
		my $gebdat_bis = shift || die;

		my $gesamt = 0;
		printf "Verteilung der Einwohner nach %s:\n",
			$e01->gebietstyp_klartext($gebiettyp);

		# Hole eine Gliederungsliste des Gebiets
		my @gliederungen = $e01->gebietsgliederungen(gebiettyp=>$gebiettyp);

		foreach my $gliederungsnummer (@gliederungen) {
			# Wieviele Einwohner gibt es hier?
			my @ew = $e01->om_nach_gebietsgliederung(
				gebiettyp => $gebiettyp,
				gebiet_nr=> $gliederungsnummer,
				# EINSCHRÄNKUNG des ALTERS!!
				gebdat_von => $gebdat_von,
				gebdat_bis => $gebdat_bis
			);
			my $anz = scalar @ew;
			my $bez = $e01->gebietsgliederung_klartext(
				gebiettyp=>$gebiettyp,
				gebiet_nr=>$gliederungsnummer);
			printf "\t(%d) %s: %d Einwohner\n", $gliederungsnummer,$bez, $anz;
			$gesamt += $anz;
		}

		printf "\t->Gesamt: %d Einwohner\n", $gesamt;
	}

Ergebnis:

	Verteilung der Einwohner nach Wahlbezirke:
	(1) Stimmbezirk 1: 938 Einwohner
	(2) Stimmbezirk 2: 725 Einwohner
	(3) Stimmbezirk 3: 685 Einwohner
	(4) Stimmbezirk 4: 686 Einwohner
	(5) Stimmbezirk 5: 817 Einwohner
	(6) Stimmbezirk 6: 807 Einwohner
	...


=head2 Jungbürger ohne Ausweis

Bürger ab 16 Jahren unterliegen der Ausweispflicht. Wenn man diese Jungbürger ohne Ausweis anschreiben will sucht man Bürger ohne jegliches Ausweisdokument mit einem bestimmten Geburtsmonat/-jahr. Normalerweise findet man hier nur vereinzelte Personen weil viele Kinder wegen Auslandsaufenthalten schon Ausweise haben.

	&jungbuerger_ohne_ausweis;

	sub jungbuerger_ohne_ausweis {
		# Wer wird diesen Monat 16?
		my ($gebjahr,$gebmonat) = ( 
			1900 + (localtime)[5] - 16, 
			1 + (localtime)[4]
		);
		printf "Hole Jungbuerger ohne jeglichen Ausweis, *=%d/%d\n", $gebmonat, $gebjahr;
		
		my @ab_jetzt_ausweispflichtig = $e01->get_oms_ohne_jegliches_dokument(
			gebmonat => $gebmonat, gebjahr => $gebjahr );

		if (@ab_jetzt_ausweispflichtig == 0) {
			printf "Kein Jungbürger ohne Ausweis für %d/%d gefunden.\n",
				$gebmonat, $gebjahr;
			return;
		}
		foreach (@ab_jetzt_ausweispflichtig) {
			my %rueck = $e01->adresse_eines_buergers(om=>$_);
			printf "%s, %s - *=%s\n", 
				$rueck{vollname},
				$rueck{rufname},
				$rueck{gebdat};
		}
	}	


=head1 Funktionen Allgemein

=head2 new

Erzeugt das grundlegende Objekt zum Zugriff auf die Datenbank und speichert
alle Konfigurationsinformationen.


Rückgabe: das Objekt mit dem man alles tun kann.

Argumente:

=over 4

=item * 

dbh=>$dbh Das DBI-Datenbankhandle (muss-Argument)

=item *

datumsformat siehe set_datumsformat (optionales Argument)

=item *

gemeindeschluessel=>'09573134', es kann nur ein Gemeindeschlüssel angegeben werden (optionales Argument)

=back 4

Beispiel:

	my $e01 = AKDB::Okewo->new(
		dbh=>$dbh, 
		gemeindeschluessel=>'09573134');

oder 

	my $e01 = AKDB::Okewo->new(
		dbh=>$dbh, 
		gemeindeschluessel=>'09573134',
		datumsformat => 'D.M.YYYY');



=cut

sub new {
	my $class = shift;
	my %args = @_;

	die "Kein dbh!" unless $args{dbh};

	my $s = {
		dbh => $args{dbh},
		prefix => 'e01admin',
		# unsere Gemeinde hat diesen Gemeindeschlüssel
		# nur Einheitsgemeinde!
		gemeindeschluessel => undef,
		# sollen SQL-Befehle in Datei geschrieben werden?
		debug_sql => 0,
		debug_sql_fn => 'sql.txt',
		debug_sql_anz_schon_geschrieben => 0,
	};

	# Stelle Oracle Datumsformat wie ich es brauche
	my $sql = "alter session set nls_date_format=\'yyyy-mm-dd\'";
	unless ( $args{dbh}->do($sql) ) {
		print "Konnte Dateformat nicht setzen.\n";
	}

	bless $s, $class;

	# Default-Datumsformat
	$s->set_datumsformat('D.M.YYYY');
	# gewünschtes Datumsformat
	$s->set_datumsformat( $args{datumsformat} ) 
		if exists $args{datumsformat};
	$s->_setze_ausweisstatus_liste;
	# Evtl. schon Gemeindeschüssel setzen wenn angegeben
	$s->zustaendig_fuer_gs($args{gemeindeschluessel})
		if $args{gemeindeschluessel};

	return $s;
}


=head2 zustaendig_fuer_gs

In der Datenbank sind auch Adressen von Bürgern eingetragen die in einen 
anderen Ort gezogen sind. 

Beispiel:

	$e01->zustaendig_fuer_gs('09573134');


Argumente:

	Der komplette Gemeindeschlüssel incl. Länderkennung (z.B. Bayern=09)

Fehlerbehandlung:

Keine.

=cut

sub zustaendig_fuer_gs {
	my $self = shift;
	my $gs;
	my $dbh = $self->{dbh};

	if (@_) {
		$self->{gemeindeschluessel} = shift;
	} else {
		return $self->{gemeindeschluessel};
	}
}

=head2 set_datumsformat

Beispiel:

	$e01->set_datumsformat('DD.MM.YYYY');

Dadurch wird die Rückgabe aller Datumsfelder gesteuert, mögliche Parameter sind:

=over 4

=item *

D.M.YYYY --> 1.12.2003 (ohne führende Null) = DEFAULT


=item *

YYYY-MM-DD --> 2003-12-1

=item *

DD.MM.YYYY --> 01.12.2003 (incl. führender Null)

=back 4

=cut

sub set_datumsformat {
	my $self = shift;
	my $format = shift;

	my $ok = 0;
	my @erlaubt = qw( YYYY-MM-DD D.M.YYYY DD.MM.YYYY );
	foreach my $checkmich (@erlaubt) {
		if ($format eq $checkmich) {
			$ok = 1;
		}
	}

	if ($ok == 1) {
		$self->{datumsformat} = $format;
	} else {
		confess("Datumsformat war \'$format\', es wurde falsch angegeben");
	}	
}


=head2 om_nach_gebietsgliederung

Alle Einwohner mit HW/EW einer bestimmten Gebietsgliederung holen. Mit der Liste der einzelnen OMs kann man dann mit Hilfe der Methode "adresse_eines_buergers" noch genauere Selektionen machen.

Rückgabe: Liste mit OMs von Bürgern mit HW/EW

Aufruf:
	
	@oms = $e01->om_nach_gebietsgliederung(
		gebiettyp=>101,
		gebiet_nr=>3);

Genauere Selektion ist möglich mit Zusatzargumenten:

	@oms = $e01->om_nach_gebietsgliederung(
		gebiettyp=>101, gebiet_nr=>3,
		# gebdat_von/_bis immer zusammen angeben!
		gebdat_von=>'2000-01-01', gebdat_bis=>'2000-12-31');

=cut

sub om_nach_gebietsgliederung {
	my $self = shift;	
	my (%args) = @_;

	# diese Argumente müssen da sein
	$self->_checke_pflichtkeys(
		rpflichtkeys => [ qw/gebiettyp gebiet_nr/ ],
		rhash => \%args);

	unless ( $self->gibt_es_diese_gebietsgliederung(%args) ) {
		confess ( sprintf "Die Gebietsgliederung Typ=%s, Gebiet_nr=%s gibt es nicht (Tabelle e01e203).", @args{ qw/gebiettyp gebiet_nr/ } )
	}

	# Prefix für die Tabellen (owner)
	my $prefix = $self->{prefix};
	my $dbh = $self->{dbh};
	my $where_gebiet = sprintf "zo.gebiettyp=%s and zo.gebiet_nr=%s", $dbh->quote($args{gebiettyp}), $dbh->quote($args{gebiet_nr});

	# Personen sind in e01e001 -> p
	# Attribute sind in e01e002 -> a
	# PLZ Ort sind in e01e200 -> o
	# Zuordnung der Objekte zu einer Gliederung e01e205 -> zo
	# Gebietsgliederung e01e205 -> gl
	my @sql_felder = (
		"p.om"
	);
	my @sql_from = (
		"${prefix}.e01e001 p",
		"${prefix}.e01e002 a", 
		"${prefix}.e01e205 zo",
		"${prefix}.e01e200 o",
	);
	my @sql_where = (
		"p.om = a.om",
		"(a.status = 'HW' or a.status = 'EW')",
		"a.objekt_nr = zo.objekt_nr",
		"o.ort_nr = a.ort_nr",
		"( p.gebdat is not null)",
		"( $where_gebiet )",
	);

	# evtl Einschränkung Geburtsdatum
	if ( exists $args{gebdat_von} ) {
		# zusätzliche Pflichtkeys
		my @k = qw/gebdat_von gebdat_bis/;
		$self->_checke_pflichtkeys(
			rpflichtkeys => \@k,
			rhash => \%args);
		# Sind das auch gültige Daten?
		my @fehler;
		foreach my $dcheck (@k) {
			if ( $args{$dcheck} =~ /^(\d{4})\-(\d{2})\-(\d{2})$/ ) {
				push @fehler, sprintf("%s - %s ist kein gültiges Datum - checkdate",$dcheck, $$dcheck)
					unless Date::Calc::check_date($1,$2,$3);
			} else {
				push @fehler, sprintf("%s - %s ist kein gültiges Datum - yyyymmdd",$dcheck, $$dcheck);
			}
		}
		if ($#fehler > -1) {
			print "$_\n" foreach @fehler;
			die;
		}
		# Ok, die Datumsformate sind ok
		# Geburtsdatum muss größergleich gebdat_von sein
		$args{gebdat_von} =~ /^(\d{4})\-(\d{2})\-(\d{2})$/;
		push @sql_where, "p.gebdat_srt >= " . $dbh->quote("$1$2$3");
		# Geburtsdatum muss kleinergleich gebdat_bis sein
		$args{gebdat_bis} =~ /^(\d{4})\-(\d{2})\-(\d{2})$/;
		push @sql_where, "p.gebdat_srt <= " . $dbh->quote("$1$2$3");
	}
	# Fertig mit Einschränkung Geburtsdatum 


	my $sql = sprintf "select %s from %s where %s",
		join(",", @sql_felder),
		join(",", @sql_from),
		join(" and ", @sql_where);

	$self->_logge_sql($sql);

	my $cur = $self->{dbh}->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "SQL war:\n$sql\n";
		printf "Fehler war: %s\n", $DBI::errstr;
		die;
	}
	$cur->execute;

	# Rückgabe ist eine Liste von oms
	my (@oms,$om);

	# Hole den einen Datensatz
	while ($om = $cur->fetchrow_array) {
		push @oms, $om;
	}

	return @oms;
}

=head2 adresse_eines_buergers

Aufruf:
	
	%rueck = $e01->adresse_eines_buergers(om=>6940);
	
Rückgabe: Hash mit genaueren Daten zum Bürger

	%rueck = (
		anrede_anschrift => 'Herrn',
		anrede_brief => 'Sehr geehrter Herr',
		rufname => 'Rüdiger',
		vollname => 'Dr. von Rückert',
		vollstrasse => 'Heinrichstraße 8a/II",
		plz => '90513',
		ort => 'Zirndorf',
		ortsteil => 'Weiherhof',
		gebdat => '1966-09-07',
		geschl => 'm'
	);

Rückgabe bei Aufruf mit om=>-1:

	%rueck = (
		anrede_anschrift => undef,
		...
	);

=cut

sub adresse_eines_buergers {
	# Es muss eine Identifikationsnummer (om) übergeben werden
	# Aufruf: me(om=>123);
	#
	my $self = shift;	
	my (%args) = @_;

	unless ($args{om}) {
		croak "Argument om wurde nicht uebergeben.";
	}
	# Bei om = -1 nur die Feldnamen zurückgeben
	if ($args{om} == -1) {
		my @felder = qw/anrede_anschrift anrede_brief rufname vollname vollstrasse plz ort gebdat geschl/;
		return map { $_ => undef } @felder;
	}
	
	# Prefix für die Tabellen (owner)
	my $prefix = $self->{prefix};
	my $dbh = $self->{dbh};

	# Personen sind in e01e001 -> p
	#   gebdat ist ein varcharfeld...
	# Attribute sind in e01e002 -> a
	# PLZ Ort sind in e01e200 -> o
	my @sql_felder = qw/
		p.om p.famname p.akadgr p.best_fname  
		p.rufname p.gebdat gebdat p.geschl
		a.strasse a.hausnr a.buchstabe
		a.teil_nr a.zusatz 
		o.plz o.ort o.ortsteil
	/;
	my @sql_from = (
		"${prefix}.e01e001 p",
		"${prefix}.e01e002 a",
		"${prefix}.e01e200 o",
	);
	my @sql_where;
	push @sql_where,'p.om = a.om'; 
	push @sql_where,'a.ort_nr = o.ort_nr'; 
	push @sql_where, sprintf('p.om = %s', $args{om});
	push @sql_where, '(a.status = \'HW\' or a.status = \'EW\')';
	push @sql_where, 'p.gebdat is not null';
	push @sql_where, sprintf('a.gs = %s', $dbh->quote($self->{gemeindeschluessel}));

	my $sql = sprintf "select %s from %s where %s",
		join(",",@sql_felder),	
		join(",",@sql_from),	
		join(" and ",@sql_where);	

	$self->_logge_sql($sql);

	my $cur = $self->_sql_los($sql);

	# Rückgabe ist ein Hash
	my %rueck;

	# Hole den einen Datensatz
	my ($einw, $counter) = (undef, 0);
	while ($einw = $cur->fetchrow_hashref) {
		$counter++;

		# Alle Felder des Datensatzes in den Rückgabehash übertragen
		%rueck = $self->_ds2hash(cur => $cur, datensatz => $einw);

		# aus dem varchar-Feld gebdat ein Datum im Format yyyy-mm-dd
		# Niemand weiß warum das kein Date-Typ ist...
		if ( $rueck{gebdat} =~ /^(\d+)\.(\d+)\.(\d+)$/ ) {
			$rueck{gebdat_yyyymmdd} = sprintf "%04d-%02d-%02d",$3,$2,$1;
			$rueck{gebdat} = $self->_datumsformat_richtigstellen($rueck{gebdat_yyyymmdd});
		}


		# Setze noch Felder für Adressdruck zusammen
		if ($rueck{geschl} eq "m") {
			$rueck{anrede_anschrift} = "Herrn";
			$rueck{anrede_brief} = "Sehr geehrter Herr";
		} else {
			$rueck{anrede_anschrift} = "Frau";
			$rueck{anrede_brief} = "Sehr geehrte Frau";
		}

		# Setze vollständigen Familiennamen zusammen
		$rueck{vollname} = join " ",@rueck{ qw(akadgr best_famname famname) };
		# Leerzeichen kürzen
		$rueck{vollname} =~ s/^\s+//;
		$rueck{plz} =~ s/^\s*(.+?)\s*$/$1/;

		# Setze Straße, Hausnummer etc. zusammen
		$rueck{vollstrasse} = sprintf "%s %s",
			$rueck{strasse},
			join("",@rueck{ qw(hausnr buchstabe teil_nr zusatz) });
	}

	if ($counter == 0) {
		return undef;
	} elsif ($counter == 1) {
		return %rueck;
	} else {
		confess "Problem: mehrere Datensätze mit om = $args{om} gefunden. SQL war $sql"
	}
}




=head1 Funktionen zur Aufteilung des Gemeindegebiets

=cut

=head2 moegliche_gemeindeschluessel

Gibt eine Liste alle Gemeindeschlüssel in der Datenbank zurück.

	@gs = $e01->moegliche_gemeindeschluessel;

Die Gemeindeschlüssel ergeben sich aus den Gebietseinteilungen in der Tabelle e01e203

=cut


sub moegliche_gemeindeschluessel {
	my $self = shift;
	my $sql = sprintf "select distinct gs from %s.e01e203",
		$self->{prefix};
	my $cur = $self->_sql_los($sql);

	my @gs;
	while (my @zeile = $cur->fetchrow_array) {
		push @gs,$zeile[0];
	}
	$cur->finish;

	return @gs;
}

=head2 gebietstypen

Das Gemeindegebiet ist in einer Reihe von Gebieten aufgeteilt: Wahlbezirke, Schulsprengel, Ortsteile etc. Jedes dieser Gebiete hat einen eindeutige Nummer.

Aufruf: 

	my @gliederungen = $e01->gebietstypen();

Rückgabe: 

Liste aller Gliederungen die es in der Gemeinde gibt. Diese Liste besteht aus Zahlen, z.B. 100, 101, 200. Was hinter den Zahlen steckt kann man so herausfinden:

	
	my (@gliederungen, $gliederung);
	@gliederungen = $e01->gebietstypen();
	foreach $gliederung (@gliederungen) {
		printf "%s - %s\n", 
			$gliederung,
			$e01->gebietstyp_klartext($gliederung);
	}



=cut

sub gebietstypen {
	my $self = shift;
	my $dbh = $self->{dbh};

	my $sql = sprintf "select distinct gebiettyp from %s.e01e203 where gs = %s order by gebiettyp", 
		$self->{prefix},
		$dbh->quote( $self->{gemeindeschluessel} );
	my $cur = $self->_sql_los($sql);

	my @g;
	while (my @zeile = $cur->fetchrow_array) {
		push @g, $zeile[0];
	}
	$cur->finish;
	
	return @g;
}

=head2 gebietstyp_klartext

Oberbegriff für diesen Gebietstyp im Klartext zurückgeben (z.B. Schulsprengel, Wahlbezirke, Ortsteile...)

Aufruf: 

	print $e01->gebietstyp_klartext(101);
	# "Ortsteile"

=cut

sub gebietstyp_klartext {
	my $self = shift;
	my $gebietstyp = shift;
	my $sql = sprintf "select klartext from %s.e01e204 where gebiettyp=%s",
		$self->{prefix},
		$self->{dbh}->quote($gebietstyp);

	my $cur = $self->_sql_los($sql);

	my @g;
	while (my @zeile = $cur->fetchrow) {
		push @g, $zeile[0];
	}
	$cur->finish;
	
	if ($#g == 0) {
		return &_strip($g[0]);
	} else {
		croak "Mehr als einen Klartext für den Gebietstyp $gebietstyp gefunden.";
	}
}


=head2 gebietsgliederungen

Holt eine Liste aller Ortsteile für den gesetzten Gemeindeschlüssel.

	@g = $e01->gebietsgliederungen(
		gebiettyp=>101);

Gebietstyp: in OK.EWO sind verschiedene Einteilungen der Gemeinde möglich (Schulsprengel, Kirchensprengel, Ortsteile). Jede Gebietsart hat eine Nummer (siehe in OK.EWO, Menü Verwalten - Gebietsgliederung - Menü Gliederung - Verzeichnispflege Gebietstyp).

Rückgabe: eine Liste von Hashs:

	@g = (
		{
			gebiet_nr => 1,
			geb_bezei => 'Zirndorf - Kernstadt'
		},
		{
			gebiet_nr => 2,
			geb_bezei => 'Weiherhof'
		},...
	);

=cut 

sub gebietsgliederungen {
	my $self = shift;
	my (%args)=@_;
	my $dbh = $self->{dbh};
	# Wenn kein Gemeindeschlüssel mitgegeben wurde 
	# einfach den ersten nehmen
	$args{gemeindeschluessel} = $self->{gemeindeschluessel};

	my $sql = sprintf "select gebiet_nr, geb_bezei from e01e203 where gs = %s and gebiettyp = %s order by gebiet_nr", 
		$dbh->quote( $args{gemeindeschluessel} ),
		$dbh->quote( $args{gebiettyp} ),
		$self->{prefix};
	my $cur = $self->_sql_los($sql);

	my @g;
	while (my $zeile = $cur->fetchrow_hashref) {
		push @g, &_strip($zeile->{GEBIET_NR}); 
	}
	$cur->finish;
	return @g;
}



=head2 gebietsgliederung_klartext

Bezeichnung für ein einzelnes Teilgebiet innerhalb eines Gebietstypen zurückgeben (z.B. Ortsteil Weinzierlein.)

Aufruf: 

	print $e01->gebietsgliederung_klartext(
		gebiettyp=>101,
		gebiet_nr=>2);
	# "Ortsteil Weinzierlein"

=cut

sub gebietsgliederung_klartext {
	my $self = shift;
	my %args = @_;
	
	$self->_checke_pflichtkeys( 
		rpflichtkeys => [ qw/gebiettyp gebiet_nr/ ],
		rhash => \%args
	);

	my $gebiettyp = $args{gebiettyp};
	my $gebiet_nr = $args{gebiet_nr};
	my $sql = sprintf "select geb_bezei from %s.e01e203 where gebiettyp=%s and gebiet_nr=%s",
		$self->{prefix},
		$self->{dbh}->quote($gebiettyp),
		$self->{dbh}->quote($gebiet_nr);

	my $cur = $self->_sql_los($sql);

	my @g;
	while (my @zeile = $cur->fetchrow) {
		push @g, $zeile[0];
	}
	$cur->finish;
	
	if ($#g == 0) {
		return &_strip($g[0]);
	} else {
		croak "Mehr als einen Klartext für den Gebietstyp $gebiettyp/Gebiet_nr $gebiet_nr gefunden.";
	}
}



=head2 gibt_es_diese_gebietsgliederung

Prüft, ob es eine angegebene Gebietsgliederung überhaupt gibt.

Aufruf:

	my $gibtes = $e01->gibt_es_diese_gebietsgliederung(
		gebiettyp => 100,
		gebiet_nr => 1);

=cut

sub gibt_es_diese_gebietsgliederung {
	my $self = shift;
	my %args = @_;
	# diese Argumente müssen da sein
	my %pflichtart = map { $_ => 1 } qw(gebiettyp gebiet_nr);
	my $pflichten = keys %pflichtart;
	foreach (keys %args) {
		$pflichten-- if $pflichtart{$_};
	}
	if ($pflichten > 0) {
		confess ("Es muessen die Argumente " . join(", ", sort keys %pflichtart) . " uebergeben werden.")
	}

	my $prefix = $self->{prefix};
	my $sql = sprintf "select count(*) from %s.e01e203 where gebiettyp=%s and gebiet_nr=%s", $prefix, @args{ qw/gebiettyp gebiet_nr/ };

	my $cur = $self->_sql_los($sql);

	my $anz = ($cur->fetchrow_array)[0];
	$cur->finish;

	$anz == 1 ? return 1 : return 0;
}



=head1 Funktionen im Bereich Passamt

=head2 get_oms_mit_dokumentablauf_in_monat

Hole eine Liste von Hashs mit allen OM (e01-interne Identifikationsnummern) aller deutschen Bürger (Staatsangehörigkeit 000) deren Ausweis/Pass im angegebenen Monat abläuft.

	@om = $e01->get_oms_mit_dokumentablauf_in_monat(
		jahr=>2003, monat=>6,
		dokumentart => 'reisepass'
	);

Pflichtargumente:

dokumentart => reisepass|personalausweis
jahr => 2003
monat => 10

Rückgabe:

	@om = [
		{	
			om => 4234,
			ablaufdatum => '25.10.2003',
			ablaufdatum_sort => '2003-10-25',
		},
		{
			om => 4239,
			ablaufdatum => '12.10.2003',
			ablaufdatum_sort => '2003-10-12',
		}, ...
	];

=cut

sub get_oms_mit_dokumentablauf_in_monat {
	my $self = shift;
	my (%args) = @_;

	# diese drei argumente müssen da sein
	my %pflichtart = map { $_ => 1 } qw(jahr monat dokumentart);
	my $pflichten = keys %pflichtart;
	foreach (keys %args) {
		$pflichten-- if $pflichtart{$_};
	}
	
	if ($pflichten > 0) {
		confess ("Es muessen die Argumente " . join(", ", sort keys %pflichtart) . " uebergeben werden.")
	}

	my $dbh = $self->{dbh};
	my $prefix = $self->{prefix};

	# PA und RP sind im Prinzip gleich. Nur die Tabelle
	# mit den Anträgen und Gültigkeitsdaten hat einen anderen Namen
	my $dokument_tab;
	if ( $args{dokumentart} eq "personalausweis" ) {
		$dokument_tab = $prefix . ".e01e014";
	} elsif ( $args{dokumentart} eq "reisepass" ) { 
		$dokument_tab = $prefix . ".e01e011";
	} else {
		confess( sprintf 'Falsche dokumentart "%s" angegeben. Erlaubt sind nur "personalausweis" und "reisepass"', $args{dokumentart} );
	}

	my $von = sprintf "%d-%d-%d",$args{jahr},$args{monat},1;
	my $bis = sprintf "%d-%d-%d",$args{jahr},$args{monat},
		Days_in_Month($args{jahr},$args{monat});

	# Alle Einwohner mit HW/EW 
	# die ein Geburtsdatum eingetragen haben (aktiver Datensatz)
	# und die hier wohnen ($where_orte)
	# ausweis-status ist egal, wenn Antrag auf neuen Ausweis
	#    gestellt wird kommt dieser Datensatz 
	# group by -> alle Datensatze zu einem Bürger holen 
	#             max(d.guelt_dat) = nur der neueste Datensatz interessiert
	# p = Personen
	# a = Adressen
	# stang = Staatsangehörigkeiten
	# o = Orte
	# d = Dokumente
	#
	my @sql_felder = (
		"p.om OM",
		"max(d.guelt_dat) ABLAUFDATUM",
	);
	my @sql_tab = (
		"${prefix}.e01e001 p",
		"${prefix}.e01e002 a",
		"${prefix}.e01e007 stang",
		"${prefix}.e01e200 o",
		"$dokument_tab d",
	);
	my @sql_bed = (
		"p.om = a.om ",
		"a.ort_nr = o.ort_nr",
		"p.om = d.om",
		"p.om = stang.om",
		"( a.status = 'EW' or a.status = 'HW')",
		"( p.gebdat is not null)",
		sprintf('(a.gs = %s)',$dbh->quote($self->{gemeindeschluessel})),
		"(stang.staatang = '000')",
		"d.status not in ('1','2','3','4')",
		"d.guelt_dat >= to_date(\'$von\','YYYY-MM-DD')",
		"d.guelt_dat <= to_date(\'$bis\','YYYY-MM-DD')",
	);
	my @sql_groupby = (
		"p.om"
	);

	my $sql = sprintf "select %s from %s where %s group by %s",
		join(",",@sql_felder),
		join(",",@sql_tab),
		join(" and ",@sql_bed),
		join(",  ",@sql_groupby);

	my $cur = $dbh->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "Fehler war " . $DBI::errstr . "\n";
		print "SQL war:\n$sql\n";
		die;
	}
	$cur->execute;

	my @om_rueck;
	while ( my $zeile = $cur->fetchrow_hashref ) {
		push @om_rueck, {
			om => $zeile->{OM},
			ablaufdatum => $self->_datumsformat_richtigstellen( $zeile->{ABLAUFDATUM} ),
			ablaufdatum_sort => $zeile->{ABLAUFDATUM}
		};
	}

	return @om_rueck;
}


=head2 ist_person_ausweispflichtig

Ist eine Person zu einem Stichtag ausweispflichtig?

Aufruf:

	my $pflichtig = $e01->ist_person_ausweispflichtig(
		om=>1234,
		stichtag=>'2003-04-01');

Rückgabe:

	1 = ja, ist ausweispflichtig

	0 = nein, ist nicht ausweispflichtig

Die Ausweispflicht wird derzeit nur anhand des Alters ermittelt. Wenn der Bürger das 16te Lebensjahr erreicht hat ist er ausweispflichtig. Insbesondere wird nicht überprüft ob die Person Ausländer ist.

=cut 

sub ist_person_ausweispflichtig {
	my $self = shift;
	my (%args) = @_;
	my $om = $args{om};
	my $gebtag = $self->_gebdat(om=>$om);
	my $alter = $self->_alter_am_stichtag(
		gebtag => $gebtag,
		stichtag=>$args{stichtag});
	# Zur Zeit wird nur das Alter überprüft
	if ($alter >= 16) {
		return 1;
	} else {
		return 0;
	}
}

=head2 noch_ausweis_vorhanden

Hat der Bürger im nächsten Monat noch einen Ausweis zur Verfügung? Die Fragen muss beantwortet werden wenn man den Bürgern einen "Warnbrief" schicken will, daß sie ab x/200x keinen Ausweis mehr haben weil der derzeitige abläuft.

	# Hole alle Personen mit ablaufenden Reisepaessen
	my @oms = $e01->get_oms_mit_dokumentablauf_in_monat(
		jahr=>2003, monat=>6,
		dokumentart => 'reisepass'
	);
	foreach $om (@oms) {
		my $r = $e01->noch_ausweis_vorhanden( 
			om => '1234',
			nach_monat=>6, jahr=>2003 );
		print "Hat schon neuen Ausweis beantragt\n"
			if $r->{hat_neu_beantragt};
		print "Hat noch einen extra Ausweis\n"
			if $r->{hat_noch_extra_pass};
	}

Rückgabe:

	$r = {
		# hat Bürger nach Ablaufmonat _noch_ einen Ausweis?
		hat_noch_extra_pass => 0|1,  
		# hat Bürger schon einen Ausweis beantragt?
		hat_neu_beantragt => 0|1,
		# ist die Person ausweispflichtig?
		ausweispflichtig => 0|1,
		# Erklaerung der beiden ersten Variablen im Klartext
		erklaerung => $erklaerung
	};

=cut 

sub noch_ausweis_vorhanden {
	my $self = shift;
	my (%args) = @_;

	# diese argumente müssen da sein
	my %pflichtart = map { $_ => 1 } qw(om nach_monat jahr);
	my $pflichten = keys %pflichtart;
	foreach (keys %args) {
		$pflichten-- if $pflichtart{$_};
	}
	if ($pflichten > 0) {
		confess ("Es muessen die Argumente " . join(", ", sort keys %pflichtart) . " uebergeben werden.")
	}
	
	# Ab wann muss ein Pass da sein? Ab dem _darauf_folgendem_
	# Monat
	my($braucht_pass_ab_monat)=$args{nach_monat} + 1;
	my($braucht_pass_ab_jahr)=$args{jahr};

	# Jahresübertrag
	if ($braucht_pass_ab_monat > 12) {
		$braucht_pass_ab_monat -= 12;
		$braucht_pass_ab_jahr += 1;
	}
	my $checke_ab = sprintf "%d-%02d-%02d",$braucht_pass_ab_jahr,
		$braucht_pass_ab_monat,1;
	
	# sortiere die Passliste nach guelt_dat aufwärts
	my @paesse = $self->get_alle_ausweisdokumente_fuer_om( om => $args{om} );
	# nur alle Vorgänge ab dem Monat ab dem ich checken soll
	@paesse = grep { $_->{guelt_dat_sort} ge $checke_ab } @paesse;

	# Bewertung der Ausweise und Anträge auf Ausweise
	@paesse = sort { $a->{guelt_dat_sort} cmp $b->{guelt_dat_sort} } @paesse;
	my $hat_noch_einen_extra_pass = 0;
	my $hat_neu_beantragt = 0; 
	my $erklaerung = "";
	foreach (@paesse) {
		if ( $_->{status} == 5) {
			$hat_noch_einen_extra_pass = 1;
			$erklaerung .= sprintf "Hat noch einen %s gültig bis %s\n", $_->{dokumentart}, $_->{guelt_dat};
		} elsif ( $_->{status} =~ /^(1|2|3|4)$/ ) {
			$hat_neu_beantragt = 1;
			$erklaerung .= sprintf "Status: %s, dokumentart: %s, guelt_dat: %s\n", 
				$self->get_ausweisstatus_klartext($_->{status}),
				$_->{dokumentart}, 
				$self->_datumsformat_richtigstellen($_->{guelt_dat});
		} else {
			# es gibt noch die Stati 6-9 und A, sollte aber nie vorkommen
			$erklaerung .= sprintf "Status: %s, dokumentart: %s, unbekannt!\n", 
				$self->get_ausweisstatus_klartext($_->{status}),
				$_->{dokumentart};
		}
		
	}
	if ($#paesse == -1) {
		$erklaerung .= "Keine weitere Pässe nach Ablauf vorhanden.";
	}

	# Ist die Person überhaupt ausweispflichtig?
	my %pflichtart = map { $_ => 1 } qw(om nach_monat jahr);
	my $person_ist_ausweispflichtig = 
		$self->ist_person_ausweispflichtig(
			om=>$args{om}, 
			stichtag=>sprintf("%d-%02d-%02d",
				$braucht_pass_ab_jahr, $braucht_pass_ab_monat,
				Days_in_Month($braucht_pass_ab_jahr, $braucht_pass_ab_monat))
		);

	return {
		hat_noch_extra_pass => $hat_noch_einen_extra_pass || 0, 
		hat_neu_beantragt => $hat_neu_beantragt || 0,
		ausweispflichtig => $person_ist_ausweispflichtig || 0,
		erklaerung => $erklaerung
	};
	
	
}


=head2 get_alle_ausweisdokumente_fuer_om 

Hole _sämtliche_ Ausweisdokumente einer Person zum Analysieren, also Personalausweise, Reisepässe, Familienausweise etc.

	@passliste = $e01->get_ausweisdokumente_fuer_om(
		om => '1234');

Argumente:

	om - Pflicht
	dokumentart

Rückgabe:

Liste von Hashs mit diesen Elementen: 

	@passliste = (
		{
		dokumentart => 'personalausweis', # oder reisepass
		antr_dat => undef,	# oder ein Datum falls vorhanden
		antr_status_klartext => 'Dokument ausgehändigt',
		guelt_dat => '14.4.2003',
		# immer in diesem Format, dient intern zum Sortieren
		guelt_dat_sort => '2003-04-14',
		status => 5,
		vorlaeufig => undef,
		},
		{...}
	);

=cut

sub get_alle_ausweisdokumente_fuer_om {
	my $self = shift;
	my (%args) = @_;

	# diese argumente müssen da sein
	my %pflichtart = map { $_ => 1 } qw(om);
	my $pflichten = keys %pflichtart;
	foreach (keys %args) {
		$pflichten-- if $pflichtart{$_};
	}
	
	if ($pflichten > 0) {
		confess ("Es muessen die Argumente " . join(", ", sort keys %pflichtart) . " uebergeben werden.")
	}

	my @ausweisliste;
	push @ausweisliste, $self->get_ausweisdokumente_fuer_om(
		om => $args{om},
		dokumentart => 'personalausweis'
	);
	push @ausweisliste, $self->get_ausweisdokumente_fuer_om(
		om => $args{om},
		dokumentart => 'reisepass'
	);

	return @ausweisliste;
}


=head2 get_ausweisdokumente_fuer_om 

Meist will man _sämtliche_ Ausweisdokumente einer Person zum Analysieren haben. Siehe -> get_alle_ausweisdokumente_fuer_om 

Hier: Hole eine Liste aller Ausweisdokumente (aber nur eine Art! personalausweis oder reisepass) für eine Person incl. einer Bewertung ob zu dem Zeitpunkt wenigstens ein gültiges Dokument vorliegt.


	@passliste = $e01->get_ausweisdokumente_fuer_om(
		om => '1234',
		dokumentart => 'personalausweis'
	);

Argumente:

	om - Pflicht
	dokumentart

Rückgabe:

Liste von Hashs mit diesen Elementen: 

	@passliste = (
		{
		dokumentart => 'personalausweis', # oder reisepass
		antr_dat => undef,	# oder ein Datum falls vorhanden
		antr_status_klartext => 'Dokument ausgehändigt',
		guelt_dat => '14.4.2003',
		status => 5,
		vorlaeufig => undef,
		},
		{...}
	);

=cut

sub get_ausweisdokumente_fuer_om {
	my $self = shift;
	my (%args) = @_;

	# diese drei argumente müssen da sein
	my %pflichtart = map { $_ => 1 } qw(om dokumentart);
	my $pflichten = keys %pflichtart;
	foreach (keys %args) {
		$pflichten-- if $pflichtart{$_};
	}
	
	if ($pflichten > 0) {
		confess ("Es muessen die Argumente " . join(", ", sort keys %pflichtart) . " uebergeben werden.")
	}

	my $dbh = $self->{dbh};
	my $prefix = $self->{prefix};
	my $om = $args{om};

	# PA und RP sind im Prinzip gleich. Nur die Tabelle
	# mit den Anträgen und Gültigkeitsdaten hat einen anderen Namen
	my $dokument_tab;
	if ( $args{dokumentart} eq "personalausweis" ) {
		$dokument_tab = $prefix . ".e01e014";
	} elsif ( $args{dokumentart} eq "reisepass" ) { 
		$dokument_tab = $prefix . ".e01e011";
	} else {
		confess( sprintf 'Falsche dokumentart "%s" angegeben. Erlaubt sind nur "personalausweis" und "reisepass"', $args{dokumentart} );
	}

	# Alle deutschen Einwohner mit HW/EW 
	# die ein Geburtsdatum eingetragen haben (aktiver Datensatz)
	# und die hier wohnen ($where_orte)
	# und die in diesem Monat/Jahr Geburtstag haben
	#
	# p = Personen
	# a = Adressen
	# stang = Staatsangehörigkeiten
	# o = Orte
	# d = Dokumente
	#
	my @sql_felder = (
		"p.om",
		"d.status",
		"d.status_dat",
		"d.vorlaeufig",
		"d.guelt_dat",
		"d.antr_dat",
	);
	my @sql_tab = (
		"${prefix}.e01e001 p",
		"${prefix}.e01e002 a",
		"${prefix}.e01e007 stang",
		"${prefix}.e01e200 o",
		"$dokument_tab d",
	);
	my @sql_bed = (
		"p.om = a.om ",
		"a.ort_nr = o.ort_nr",
		"p.om = stang.om",
		"p.om = d.om",
		"( a.status = 'EW' or a.status = 'HW')",
		"( p.gebdat is not null)",
		sprintf('(a.gs = %s)',$dbh->quote($self->{gemeindeschluessel})),
		"(stang.staatang = '000')",
		"p.om = \'$om\'",
	);

	my $sql = sprintf "select %s from %s where %s",
		join(",",@sql_felder),
		join(",",@sql_tab),
		join(" and ",@sql_bed);

	$self->_logge_sql($sql);

	my $cur = $dbh->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "Fehler war " . $DBI::errstr . "\n";
		print "SQL war:\n$sql\n";
		die;
	}
	$cur->execute;

	my @doks;
	while ( my $zeile = $cur->fetchrow_hashref ) {
		push @doks, {
			dokumentart => $args{dokumentart},
			guelt_dat => $self->_datumsformat_richtigstellen($zeile->{GUELT_DAT}) || undef,
			# zum Sortieren zusätzlich noch in YYYY-MM-DD
			guelt_dat_sort => $zeile->{GUELT_DAT} || undef,
			status => $zeile->{STATUS} || undef,
			antr_status_klartext => $self->get_ausweisstatus_klartext( $zeile->{STATUS} ) || undef,
			antr_dat => $self->_datumsformat_richtigstellen($zeile->{ANTR_DAT}) || undef,
			vorlaeufig => $zeile->{VORLAEUFIG} || undef,
		};
	}

	return @doks;
}


=head2 get_oms_ohne_jegliches_dokument

Hole eine Liste aller Personen die weder Personalausweis noch Reisepass haben

	@om = $e01->get_oms_ohne_jegliches_dokument

Das selbe nur für einen Monat:
	
	@om = $e01->get_oms_ohne_jegliches_dokument
		gebmonat => 12,
		gebjahr => 1980
	);

=cut

sub get_oms_ohne_jegliches_dokument {
	my $self = shift;
	my (%args)=@_;
	# Ist gebmonat _und_ gebjahr angegeben?
	my $acount = 0;
	$acount++ if exists $args{gebmonat};
	$acount++ if exists $args{gebjahr};
	unless ($acount == 0 or $acount = 2) {
		confess ("Bitte gebmonat _und_ gebjahr angeben.");
	}

	my (@om_ohne_pa, @om_ohne_rp);
	if ($acount == 0) {
		@om_ohne_pa = $self->get_oms_ohne_dokument (
			dokumentart => 'personalausweis',
		);
		@om_ohne_rp = $self->get_oms_ohne_dokument (
			dokumentart => 'reisepass',
		);
	}

	if ($acount == 2) {
		$args{gebmonat} = sprintf "%02d", $args{gebmonat};
		unless (length $args{gebjahr} == 4) {
			confess("Bitte gebjahr _vier_stellig angeben");
		}

		@om_ohne_pa = $self->get_oms_ohne_dokument (
			dokumentart => 'personalausweis',
			gebmonat => $args{gebmonat},
			gebjahr => $args{gebjahr}
		);
		@om_ohne_rp = $self->get_oms_ohne_dokument (
			dokumentart => 'reisepass',
			gebmonat => $args{gebmonat},
			gebjahr => $args{gebjahr}
		);

	
	}

	# Suche die Schnittmenge alles. Diese haben _kein_ Ausweisdokument
	my (%om_ohne_pa, %om_ohne_rp);
	%om_ohne_rp = map { $_ => 1 } @om_ohne_rp;
	%om_ohne_pa = map { $_ => 1 } @om_ohne_pa;

	my %om_ohne_irgendwas;
	foreach (keys %om_ohne_pa) {
		if ( exists $om_ohne_rp{$_} ) {
			$om_ohne_irgendwas{$_} = 1;
		}
	}

	return keys %om_ohne_irgendwas;
}

=head2 get_oms_ohne_dokument

Hole eine Liste mit allen OM (e01-interne Identifikat0ionsnummern) aller deutschen Bürger deren die keinen Pass oder die keinen Personalausweis haben.

	@om = $e01->head2 get_oms_ohne_dokument (
		dokumentart => 'reisepass');

dokumentart kann sein: reisepass|personalausweis

Zusätzlich kann man auch noch Geburtsmonat/-jahr übergeben. Dann kommen nur Bürger dieses Zeitraums. Man benutzt das zum Beispiel um Bürger anzuschreiben die in einem bestimmten Monat ausweispflichtig werden.

	@om = $e01->head2 get_oms_ohne_dokument (
		dokumentart => 'reisepass',
		gebmonat => 12,
		gebjahr => 1980
	);

=cut

sub get_oms_ohne_dokument {
	my $self = shift;
	my (%args) = @_;

	unless ($args{dokumentart}) {
		confess ("Dokumentart personalausweis|reisepass muss mit angegeben werden.");
	}

	# Ist gebmonat _und_ gebjahr angegeben?
	my $acount = 0;
	$acount++ if exists $args{gebmonat};
	$acount++ if exists $args{gebjahr};
	unless ($acount == 0 or $acount = 2) {
		confess ("Bitte gebmonat _und_ gebjahr angeben.");
	}
	if ($acount == 2) {
		$args{gebmonat} = sprintf "%02d", $args{gebmonat};
		unless (length $args{gebjahr} == 4) {
			confess("Bitte gebjahr _vier_stellig angeben");
		}
	}

	my $dbh = $self->{dbh};
	my $prefix = $self->{prefix};

	# PA und RP sind im Prinzip gleich. Nur die Tabelle
	# mit den Anträgen und Gültigkeitsdaten hat einen anderen Namen
	my $dokument_tab;
	if ( $args{dokumentart} eq "personalausweis" ) {
		$dokument_tab = $prefix . ".e01e014";
	} elsif ( $args{dokumentart} eq "reisepass" ) { 
		$dokument_tab = $prefix . ".e01e011";
	}

	# Alle deutschen Einwohner mit HW/EW 
	# die ein Geburtsdatum eingetragen haben (aktiver Datensatz)
	# und die hier wohnen ($where_orte)
	# status ist _nicht_: 1,2,3,4 (wäre: neuer Antrag schon gestellt)
	my @sql_felder = ("distinct p.om");
	my @sql_from = (
		"${prefix}.e01e001 p",
		"${prefix}.e01e002 a",
		"${prefix}.e01e007 stang",
		"${prefix}.e01e200 o",
		"$dokument_tab d"
	);
	my @sql_where = (
		"p.om = a.om",
		"p.om = stang.om",
		"a.ort_nr = o.ort_nr",
		"p.om = d.om(+) ",
		"( a.status = 'EW' or a.status = 'HW')",
		"( p.gebdat is not null )",
		"( stang.staatang = '000' )",
		"( d.status is null )",
		sprintf('(a.gs = %s)',$dbh->quote($self->{gemeindeschluessel})),
	);
	# wenn nur Leute ohne Ausweise aus einem bestimmten 
	# Monat gesucht werden
	if ($args{gebmonat} and $args{gebjahr}) {
		push @sql_where, sprintf "substr(p.gebdat,7,4) = '%s'",
			$args{gebjahr};
		push @sql_where, sprintf "substr(p.gebdat,4,2) = '%s'",
			$args{gebmonat};
	}

	my $sql = sprintf "select %s from %s where %s",
		join(",",@sql_felder),
		join(",",@sql_from),
		join(" and ",@sql_where);

	$self->_logge_sql($sql);

	my $cur = $dbh->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "Fehler war " . $DBI::errstr . "\n";
		print "SQL war:\n$sql\n";
		die;
	}
	$cur->execute;

	my @oms;
	while ( my @zeile = $cur->fetchrow ) {
		push @oms, $zeile[0];
	}
	return @oms;
}



=head2 get_ausweisstatus_klartext

Der Antrag auf einen Ausweis wird mit Statusnummern gekennzeichnet. Hier kann man den Klartext dazu bekommen.

Aufruf:

	printf 'Status für %d ist "%s"\n',
		3, $e01->get_ausweisstatus_klartext(3);

Üblicherweise gibt es diese Stati:

=over 4

=item *
1 Antrag erstellt

=item *
2 Antrag verschickt

=item *
3 Dokument bei Meldebörde eingetroffen

=item *
4 Antragsteller zur Abholung benachrichtigt

=item *
5 Dokument ausgehändigt

=item *
6 Dokument als verloren gemeldet

=item *
7 Dokument amtlich geändert

=item *
8 Dokument mit Ausstell.beh. abgerechnet

=item *
9 Dokument wurde amtlich eingezogen

=item *
A Dokument ungültig

=back 4

=cut

sub get_ausweisstatus_klartext {
	my ($self, $nr) = (shift, shift);
	return $self->{ausweisstatus}->{$nr} || undef;
}

=head2 ausweisart_klartext

Gibt einen Klartext für Textausgaben zurück

	rp -> Reisepass
	reisepass -> Reisepass
	pa -> Personalausweis
	personalausweis -> Personalausweis

Aufruf:

	print $e01->ausweisart_klartext('rp');

=cut

sub ausweisart_klartext {
	my $self = shift;
	my $arg = shift;

	my %gueltig = (
		rp => 'Reisepass',
		reisepass => 'Reisepass',
		pa => 'Personalausweis',
		personalausweis => 'Personalausweis',
	);

	# nur diese Argumente sind zugelassen
	unless ( exists $gueltig{$arg} ) {
		confess sprintf("Falsches Argument %s, gueltig sind nur: %s\n",
			join("|",sort keys %gueltig));
	}

	return $gueltig{$arg};
}


=head2 get_status_dokument_fuer_om

Bestimme Status für ein bestimmtes Ausweisdokument.

	my %st = $e01->get_status_dokument_fuer_om(
		om => 480,
		ausweisart => 'personalausweis' );

Rückgabe:

	%pa = (
		ausweisart => 'personalausweis',
	 	status => 3,
		status_klartext = 'Dokument bei Meldebehörde eingetroffen'

Wenn kein Ausweis vorliegt dann wird als Status -1 zurückgegeben.

Argumente:

	om (Pflicht)

	ausweisart = personalausweis|reisepass (Pflicht)

=cut

sub get_status_dokument_fuer_om {
	# Wenn Status:
	# 1-4 Antrag am Laufen
	# 5 = Hat Dokument
	# 6 = ?
	# 7 = ? 
	# kein Datensatz -> hat kein Dokument
	#
	my $self = shift;
	my %args = @_;
	# In welcher Tabelle suchen? 
	my $tabelle;

	unless ($args{om}) {
		croak "Argument om wurde nicht uebergeben.";
	}
	unless ($args{ausweisart} =~ /^(personalausweis|reisepass)$/ ) {
		croak "Argument ausweisart wurde nicht uebergeben.";
	} else {
		$tabelle = "e01e014" if $1 eq "personalausweis";
		$tabelle = "e01e011" if $1 eq "reisepass";
	}

	my $dbh = $self->{dbh};
	# Prefix für die Tabellen (owner)
	my $prefix = $self->{prefix};

	my $sql =<<EOSQL2;
select om, guelt_dat, status 
from ${prefix}.${tabelle}
where om = $args{om}  
EOSQL2

	my $cur = $self->{dbh}->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "SQL war:\n$sql\n";
		die;
	}
	$cur->execute;

	my (%pa, $akt);
	my $counter = 0;
	while ($akt = $cur->fetchrow_hashref) {
		$counter++;
		%pa = $self->_ds2hash(cur => $cur, datensatz => $akt);
	}

	if ( $counter == 0 ) {
		# Keinen Eintrag für Personalausweis gefunden
		# -> hat keinen
		$pa{status} = -1;
		$pa{ausweisart} = $args{ausweisart};
		$pa{status_klartext} = $self->gebe_status_klartext( $pa{status} );
		return %pa;
	} elsif ( $counter == 1 ) {
		# Eintrag für einen Personalausweis gefunden
		$pa{ausweisart} = $args{ausweisart};
		$pa{status_klartext} = $self->gebe_status_klartext( $pa{status} );
		return %pa;
	} else {
		confess "Da stimmt was nicht. Mehrere Eintraege in Tabelle $tabelle \($args{ausweisart}\)\nfuer om=$args{om}";
	}
}


=head1 Funktionen im Bereich Einwohnermeldeamt

=head2 get_oms_mit_geburtstag_in_monat

Hole eine Liste aller Personen die in einem angegebenen Monat/Jahr geboren sind. Einschränkung: nur Einwohner mit Hauptwohnsitz.

Aufruf:

	@om = $e01->get_oms_mit_geburtstag_in_monat(
		gebmonat => 12,
		gebjahr => 1980
	);

oder wenn man nur deutsche Personen haben will (z.B. bei Anschreiben wegen Passpflicht):

	@om = $e01->get_oms_mit_geburtstag_in_monat(
		gebmonat => 12,
		gebjahr => 1980,
		nur_deutsche => 1,
	);

=cut

sub get_oms_mit_geburtstag_in_monat {
	my $self = shift;
	my (%args) = @_;

	# diese argumente müssen da sein
	my %pflichtart = map { $_ => 1 } qw(gebjahr gebmonat);
	my $pflichten = keys %pflichtart;
	foreach (keys %args) {
		$pflichten-- if $pflichtart{$_};
	}
	
	if ($pflichten > 0) {
		confess ("Es muessen die Argumente " . join(", ", sort keys %pflichtart) . " uebergeben werden.")
	}

	my $nur_deutsche=0;
	if ( $args{nur_deutsche} ) {
		$nur_deutsche=1;
	}

	my $dbh = $self->{dbh};
	my $prefix = $self->{prefix};

	# Gebmonat/jahr für SQL frisieren
	$args{gebmonat} = sprintf "%02d",$args{gebmonat};
	unless ( length($args{gebjahr}) ) {
		confess("Geburtsjahr $args{gebjahr} wurde nicht 4stellig angegeben!");
	}

	# Alle deutschen Einwohner mit HW/EW 
	# die ein Geburtsdatum eingetragen haben (aktiver Datensatz)
	# und die hier wohnen ($where_orte)
	# und die in diesem Monat/Jahr Geburtstag haben
	#
	# p = Personen
	# a = Adressen
	# stang = Staatsangehörigkeiten
	# o = Orte
	#
	my @sql_felder = (
		"p.om"
	);
	my @sql_tab = (
		"${prefix}.e01e001 p",
		"${prefix}.e01e002 a",
		"${prefix}.e01e200 o",
	);
	my @sql_bed = (
		"p.om = a.om ",
		"a.ort_nr = o.ort_nr",
		"( a.status = 'EW' or a.status = 'HW')",
		"( p.gebdat is not null)",
		sprintf('(a.gs = %s)',$dbh->quote($self->{gemeindeschluessel})),
		# gebdat ist kein Datefeld!
		sprintf( "substr(p.gebdat,7,4) = '%s'", $args{gebjahr}),
		sprintf("substr(p.gebdat,4,2) = '%s'", $args{gebmonat}),
	);
	# Abfrage modifizieren wenn nur deutsche Personen gesucht sind
	if ($nur_deutsche) {
		push @sql_tab, "${prefix}.e01e007 stang";
		push @sql_bed, "p.om = stang.om";
		push @sql_bed, "(stang.staatang = '000')";
	}

	my $sql = sprintf "select %s from %s where %s",
		join(",",@sql_felder),
		join(",",@sql_tab),
		join(" and ",@sql_bed);

	$self->_logge_sql($sql);

	my $cur = $dbh->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "Fehler war " . $DBI::errstr . "\n";
		print "SQL war:\n$sql\n";
		die;
	}
	$cur->execute;

	my @oms;
	while ( my $zeile = $cur->fetchrow_hashref ) {
		push @oms, $zeile->{OM};
	}

	return @oms;
}



=head1 Interne Funktionen und Debugging

=head2 _strip 

Interne Routine: Löscht Leerzeichen am Ende eines Strings.

=cut

sub _strip {
	my $stri = shift;
	$stri =~ s/\s+$//g;
	return $stri;
}


=head2 _jetzt_plus_x_monate

Monat/Jahr von heute +1 Monat. Rückgabe ist eine Liste ($jahr, $monat)

=cut

sub _jetzt_plus_x_monate {
	shift;	# Klasse egal
	my($plus_x)=shift || 0;

	my ($jahr) = (Today)[0];
	my ($monat) = (Today)[1] + $plus_x;
	if ($monat > 12) {
		$monat -= 12;
		$jahr++;
	}
	return ($jahr,$monat);

}


=head2 set_debug_sql

Logge SQL-Befehle in Datei sql.txt wenn $e01->set_debug_sql(1). Default ist 0.

=cut

sub set_debug_sql {
	my $self = shift;
	my $wert = shift;

	$self->{debug_sql} = $wert;
}


=head2 _datumsformat_richtigstellen

Interne Routine.

Konvertiere internes Datumsformat YYYY-MM-DD in das vom Benutzer gewünschte
(siehe set_datumsformat), z.B. D.M.YYYY

=cut 

sub _datumsformat_richtigstellen {
	my $self = shift;
	my $dat_org = shift;

	if ( $dat_org =~ /^(\d+)\-(\d+)\-(\d+)$/ ) {
		if ( $self->{datumsformat} eq 'YYYY-MM-DD' ) {
			# Default, nichts verändern
			return $dat_org;
		}
		if ( $self->{datumsformat} eq 'DD.MM.YYYY' ) {
			return sprintf "%02d.%02d.%d",$3,$2,$1;
		}
		if ( $self->{datumsformat} eq 'D.M.YYYY' ) {
			return sprintf "%d.%d.%d",$3,$2,$1;
		}
	} else {
		return undef;
	}
}


=head2 _gebdat

Interne Routine. Hole Geburtsdatum einer Person.

Aufruf:

	my $gebdat = $e01->_gebdat(12243);

Rückgabe:

	Geburtsdatum im Format yyyy-mm-dd

=cut

sub _gebdat {
	# Es muss eine Identifikationsnummer (om) übergeben werden
	# Aufruf: me(om=>123);
	#
	my $self = shift;	
	my (%args) = @_;

	unless ($args{om}) {
		croak "Argument om wurde nicht uebergeben.";
	}
	
	# Prefix für die Tabellen (owner)
	my $prefix = $self->{prefix};

	# Personen sind in e01e001 -> p
	#   gebdat ist ein varcharfeld...
	my $sql =<<EOSQL1;
select 
	p.gebdat gebdat
from 
	${prefix}.e01e001 p
where
	p.gebdat is not null
	and p.om = $args{om}
EOSQL1
	$self->_logge_sql($sql);

	my $cur = $self->{dbh}->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "SQL war:\n$sql\n";
		die;
	}
	$cur->execute;

	my $rueck;

	# Hole den einen Datensatz
	my $gebdat = ($cur->fetchrow_array)[0];

	# aus dem varchar-Feld gebdat ein Datum im Format yyyy-mm-dd
	# Niemand weiß warum das kein Date-Typ ist...
	if ( $gebdat =~ /^(\d+)\.(\d+)\.(\d+)$/ ) {
		$gebdat = sprintf "%04d-%02d-%02d",$3,$2,$1;
		return $gebdat;
	} else {
		die sprintf("Geburtsdatum von om=%s ist %s\n",$args{om},$gebdat);
	}
}

=head2 _alter_am_stichtag

Gibt das Alter einer Person zu einem Stichtag zurück. Wenn jemand am 
Stichtag 16ten Geburtstag hat ist das Alter 16.

Aufruf:

	my $alter = $e01->_alter_am_stichtag (
		gebtag => '1987-04-03',
		stichtag=>'2003-04-01');

=cut

sub _alter_am_stichtag {
	my $self = shift;
	my (%args) = @_;
	my $om = $args{om};
	my ($stichtag,$gebtag) = @args{ qw/stichtag gebtag/ };

	$stichtag =~ /^(\d+)-(\d+)-(\d+)$/;
	my ($stich_y,$stich_m,$stich_d)=($1,$2,$3);
	$gebtag =~ /^(\d+)-(\d+)-(\d+)$/;
	my ($gebtag_y,$gebtag_m,$gebtag_d)=($1,$2,$3);

	my ($delta_y,$delta_m,$delta_d) = 
		Delta_YMD(
			$gebtag_y,$gebtag_m,$gebtag_d,
			$stich_y,$stich_m,$stich_d);

	my $alter = $delta_y + ($delta_m / 12) + ($delta_d / 365);
	return $alter;

}

=head2 _logge_sql

Interne Routine. Logge SQL-Befehle in Datei sql.txt falls $e01->set_debug_sql(1)

=cut

sub _logge_sql {
	my $self = shift;
	my $sql = shift;
	# nix loggen wenn nicht gewünscht
	return unless $self->{debug_sql};
	# lösche Logdatei falls erster SQL-Befehl
	if ( $self->{debug_sql_anz_schon_geschrieben} == 0 ) {
		unlink $self->{debug_sql_fn};
	}
	$self->{debug_sql_anz_schon_geschrieben}++;
	open LOG, ">>", $self->{debug_sql_fn};
	print LOG caller(1) . "\n";;
	print LOG $sql . "\n\n";
	close LOG;
}


=head2 _setze_ausweisstatus_liste

Interne Routine. Holt die Stati für das Passverfahren aus der Tabelle e01e256

=cut

sub _setze_ausweisstatus_liste {
	my $self = shift;
	my $dbh = $self->{dbh};
	my $sql = "select status, klartext_l from e01admin.e01e256";

	my $cur = $dbh->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "SQL war:\n$sql\n";
		die;
	}
	$cur->execute;

	my %status;
	my $ctr = 0;
	while (my $zeile = $cur->fetchrow_hashref) {
		my $text = $zeile->{KLARTEXT_L};
		# Leerzeichen weg
		$text =~ s/^\s*(.+?)\s*$/$1/;
		$status{ $zeile->{STATUS} }  = $text;
		$ctr++;
	}
	$cur->finish;

	if ($ctr == 0) {
		confess("Konnte Liste mit Stati fuer Ausweise nicht abfragen. SQL war $sql");
	}

	$self->{ausweisstatus} = \%status;
}

sub _ds2hash {
	# wir haben einen Datensatz aus einer Tabelle in einem
	# Hashref. Das soll überführt werde in einen Hash
	# Alle Felder des Datensatzes in den Rückgabehash übertragen
	# select x,y from ichweissnet
	# ... $ds = $cur->fetchrow_hashref
	# _ds2hash -> { x => "ju", y => "hei" }
	#
	my ($self)= (shift);
	my %args = @_;
	my $cur = $args{cur};
	my $datensatz = $args{datensatz};

	my %strukt;

	my $i=0;
	foreach ( @{$cur->{NAME}} ) {
		$strukt{ lc $_ } = $datensatz->{ $_ };
		$i++;
	}
	return %strukt;
}

=head2 _sql_los

Interne Routine. Macht prepare und execute gegen DB

=cut 

sub _sql_los {
	my $self = shift;
	my $sql = shift;
	my $cur = $self->{dbh}->prepare($sql);
	unless ($cur) {
		print "Prepare fuer SQL-Abfrage nicht erfolgreich.\n";
		print "SQL war:\n$sql\n";
		print "Datenbankfehlermeldung war: $DBI::errstr\n";
		printf "Aufrufende Routine: %s\n", (caller(1))[3]; 
		croak;
	}
	$cur->execute;
	return $cur;
}

=head2 _gebe_ersten_gemeindeschluessel

Den ersten Gemeindeschlüssel aus der Datenbank holen der gefunden wird. Das funktioniert nur bei einer Einheitsgemeinde zufriedenstellend! Nicht bei einer Verwaltungsgemeinschaft verwenden!

=cut 

sub _gebe_ersten_gemeindeschluessel {
	my $self = shift;
	return ( $self->get_moegliche_gemeindeschluessel )[0];
}

=head2 _checke_pflichtkeys

Interne Routine. Sind alle Pflichtkeys mit übergeben worden?

Aufruf:

	$self->_checke_pflichtkeys( 
		rpflichtkeys => [ qw/gebiettyp gebiet_nr/ ],
		rhash => \%args
	);

Im Fehlerfall stirbt das Programm.

=cut

sub _checke_pflichtkeys {
	shift;
	my (%args) = @_;
	my ($rpflichtkeys,$rhash);

	my @fehler;
	# Zwei Pflichtargumente
	foreach ( qw/rpflichtkeys rhash/ ) {
		push @fehler, "Argument $_ wurde nicht uebergeben."
			unless exists $args{$_};
	}

	# Wenn noch nicht mal die Pflichtargumente übergeben wurden
	# brauche ich gar nicht weiter prüfen
	if ($#fehler == -1) {
		# Erstes Argument muss ein Verweis auf eine Liste sein
		$rpflichtkeys = $args{rpflichtkeys};
		unless (ref $rpflichtkeys eq "ARRAY") {
			push @fehler, "Argument rpflichtkeys ist kein Array.";
		}

		# Zweites eine Verweis aus einen Hash
		$rhash = $args{rhash};
		unless (ref $rhash eq "HASH") {
			push @fehler, "Argument rhash ist kein Hash.";
		}
	}

	if ($#fehler > -1) {
		printf "Hier ist %s\nFalscher Aufruf von %s\n",
			(caller(0))[3],
			(caller(1))[3];
		foreach (@fehler) {
			print "$_\n";
		}
		die;
	}

	# Argumente wurden richtig übergeben, weiter...
	my @pflichtkeys = @{$rpflichtkeys};
	my %hash = %{$rhash};

	# diese Argumente müssen da sein
	my %pflichtart = map { $_ => 1 } @pflichtkeys;
	my $pflichten = keys %pflichtart;
	foreach (keys %hash) {
		$pflichten-- if $pflichtart{$_};
	}
	if ($pflichten > 0) {
		confess ("Es muessen die Argumente " . join(", ", sort keys %pflichtart) . " uebergeben werden.")
	}
	return 1;
}


1;

=head1 PROBLEME, EINSCHRÄNKUNGEN

Das Modul ist nur für eine Einheitsgemeinde getestet worden. Verwaltungsgemeinschaften müssten sich anhand Ihres Gemeindeschlüssels durch alle Gemeinden einzeln durcharbeiten.

=head1 HAFTUNG

Ich hafte für nichts. Dieses Modul ist nach meinem besten Wissenstand programmiert worden, alle Ergebnisse sind bis ins letzte Detail zu überprüfen.

=head1 HISTORY

V1.00 - Init

=head1 AUTHOR

Richard Lippmann <edv@zirndorf.de>

=cut
