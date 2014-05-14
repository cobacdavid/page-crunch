#!/bin/sh
# the next line restarts using wish \
exec tclsh "$0" "$@"

# page-crunch.tcl
#
# Ce fichier est un frontend pour quelques commandes basiques de
# manipulation de fichiers postscripts et pdf.
#
# Licence GNU/GPL

# auteur : david cobac
# fin août 2003 / fin aout 2006
# avec l'aide :
#    - du forum fr.comp.lang.tcl
#    - des groupes LiLaT et AmiTeX
#    - de Georges Khaznadar pour :
#             ses conseils avises
#             le nom 'page-crunch' remplacant de FEpsnup
#             moins porteur ;-)
#    - de Sylvain Beucler pour :
#             option --media pour gv >3.6
#             compatibilité avec gettext
#
# mainteneur du paquet Debian : Sylvain Beucler

# version 1.0.1 du 04 novembre 2006
# 1.0 -> 1.0.1
# bug trouvé sur le remplissage "a la main" du champ In

# version 1.0 du 14 septembre 2006
# 0.9.9 -> 1.0
# wish en version tk8.3 charge une version trop ancienne de msgcat
# bug reference par O. Cortes

# version 0.9.9 du 28 aout 2006
# 0.9.8 -> 0.9.9
# Correction des appels mcload

# version 0.9.8 du 28 aout 2006
# 0.9.7 -> 0.9.8
# Compatibilite avec gettext pour la traduction

# version 0.9.7 du 25 aout 2006
# 0.9.6 -> 0.9.7
# Changement du chargement les langues disponibles

# version 0.9.6 du 25 aout 2006
# 0.9.5 -> 0.9.6
# version anglais/français avec msgcat

# version 0.9.5 du 22 juin 2006
# 0.9.4 -> 0.9.5
# ajout le l'option -match pour gérer les dimensions auto.
# lors de la conversion pdftops

# version 0.9.4 du 21 juin 2006
# 0.9.3 -> 0.9.4 :
# ajout de l'option --media pour les versions de gv > 3.6
# modification du réarrangement : les formats restent disponibles

# version 0.9.3 du 28 août 2004
# 0.9.2 -> 0.9.3 :
# ajout des dimensions des pages pour les conversions pdf<->ps

# il semblerait qu'avec l'utilisation de acroread le nettoyage des
# fichiers temporaires soient inopérants, acroread sort un message
# d'erreur signifinant un pb d'encodage en iso8859-15... arrêtant
# prématurément la procédure qui devrait se terminer par le nettoyage.

package require Tk

############# partie msgcat
package require msgcat
namespace import msgcat::*
# pour tester :
#::msgcat::mclocale en
set listeChemins [list [file dirname [info script]] \
    /usr/local/share/page-crunch \
    /usr/share/page-crunch]
foreach cheminLocale $listeChemins {
    if {[mcload $cheminLocale]} break
}
proc _ {s} {return [::msgcat::mc $s]}
#############

namespace eval psnup {
    namespace export *

    variable version 1.0.2
    
    catch {exec psnup -v} sortie
    variable psnupinfo [split $sortie \n]
    variable psnupversion [lindex $psnupinfo 0]
    
    catch {exec pstops} sortie
    variable pstopsinfo [split $sortie \n]
    variable pstopsversion [lindex $pstopsinfo 0]

    catch {exec psselect -v} sortie
    variable psselectinfo [split $sortie \n]
    variable psselectversion [lindex $psselectinfo 0]

    variable visu
    if {$tcl_platform(platform)=="windows"} {
	variable visuPS {gsview32}
	variable visuPDF {gsview32}
    } else {
	variable visuPS gv
	variable visuPDF xpdf
    }
    
    variable NomFichier
    variable NomFichierS
    variable NomFichierPS

    variable NomFichierPSS
    variable ComPDFtoPS pdftops
    variable ComPDFtoPSW pdf2ps
    variable ComPStoPDF ps2pdf
    variable ListeOptions
    variable ajout
    variable bordure
    variable ligne
    variable autorota
    variable col
    variable marges
    variable mentree a4
    variable msortie a4
    variable mreunions 2
    variable munitbordure pt
    variable munitmarges cm
    variable munitligne pt
    variable mreductions auto
    variable mrotations auto
    variable pt 0.3515; # en cm
    variable font_infos {Helvetica 10}
    variable rearrange
    variable livre
    variable selection 0
    variable parite 3
}

if {$tk_version<8.4} {
    proc labelframe {w args} {
	set options ""
	foreach {opt val} $args {
	    if {$opt=="-labelanchor"||$opt=="-text"} {continue}
	    lappend options $opt $val
	}
	eval frame $w $options -relief groove -bd 2
	return $w
    }
}

# psnup::gui
#    construit l'interface graphique
#
# Args :
#    
# Res :
#    affichage de l'interface
#    mise en place des valeurs booléennes des choix

proc psnup::gui { } {
    
    set reunions [list 1 2 3 4 5 6 7 8 9 10]
    set formats [list a3 a4 a5 b5 letter legal tabloid statement executive\
		     folio quarto 10x14]
    set reductions [list auto 1 0.9 0.8 0.7 0.6 0.5 0.4 0.3 0.2 0.1 0]
    set rotations [list auto +90 -90]
    set unit [list cm pt in]
    ###################################################################
    # cadre des fichiers
    ###################################################################
    labelframe .flffichiers -labelanchor nw -text [_ Files]
    set f .flffichiers
    # choix des fichiers à traiter
    # source
    label $f.l -text [_ in]
    entry $f.e -width 50 -bg white
    $f.e insert end $psnup::NomFichier
    button $f.s -text "..." -command "psnup::ChoixFichier $f"
    grid $f.l -row 1 -column 1 -sticky e
    grid $f.e -row 1 -column 2
    grid $f.s -row 1 -column 3
    #info
    label $f.lI1 -text [_ infos] -font $psnup::font_infos
    label $f.lI2 -anchor w -font $psnup::font_infos
    grid $f.lI1 -row 2 -column 1 -sticky e
    grid $f.lI2 -row 2 -column 2 -sticky w
    # sortie
    label $f.lS -text [_ out]
    entry $f.eS -width 50 -bg white
    $f.eS insert end $psnup::NomFichierS
    button $f.sS -text "..." -command "psnup::ChoixFichier $f S"
    grid $f.lS -row 3 -column 1 -sticky e
    grid $f.eS -row 3 -column 2
    grid $f.sS -row 3 -column 3
    
    ###################################################################
    # réunion de xx pages
    ###################################################################
    set f .freunion;frame $f
    label $f.l -text [_ "Pages per sheet"]
    eval tk_optionMenu $f.cb psnup::mreunions $reunions
    $f.cb configure -width 3
    pack $f.l -side left
    pack $f.cb

    frame .maf
    ###################################################################
    # cadre des formats
    ###################################################################
    set f .maf.flfformats
    labelframe $f -labelanchor nw -text [_ Formats]
    # format entrée
    label $f.lentree -text [_ in]
    eval tk_optionMenu $f.cbentree psnup::mentree $formats
    $f.cbentree configure -width 10
    # format sortie
    label $f.lsortie -text [_ out]
    eval tk_optionMenu $f.cbsortie psnup::msortie $formats
    $f.cbsortie configure -width 10
    grid $f.lentree -row 1 -column 1 -sticky e
    grid $f.cbentree -row 1 -column 2
    grid $f.lsortie -row 2 -column 1 -sticky e
    grid $f.cbsortie -row 2 -column 2
    pack $f -side left

    ###################################################################
    # cadre des marges
    ###################################################################
    set f .maf.flfmarges
    labelframe $f -labelanchor nw -text [_ Strokes]
    # bordure (marges sources)
    checkbutton $f.cbsources -indicatoron 1 -variable psnup::bordure\
	-text [_ "Source pages stroke"]
    bind $f.cbsources <1> "psnup::cb %W bordure"
    entry $f.ebordure -width 3 -state disabled -relief flat
    eval tk_optionMenu $f.omsources  psnup::munitbordure $unit
    $f.omsources configure -width 3
    # marges (marges sorties)
    checkbutton $f.cbsorties -indicatoron 1 -variable psnup::marges\
	-text [_ "Output pages stroke"]
    bind $f.cbsorties <1> "psnup::cb %W marges"
    entry $f.emarges -width 3 -state disable -relief flat
    eval tk_optionMenu $f.omsorties  psnup::munitmarges $unit
    $f.omsorties configure -width 3

    grid $f.cbsources -row 1 -column 1 -sticky w
    grid $f.ebordure -row 1 -column 3
    grid $f.omsources -row 1 -column 4
    grid $f.cbsorties -row 2 -column 1 -sticky w
    grid $f.emarges -row 2 -column 3
    grid $f.omsorties -row 2 -column 4
    pack $f -side right -fill x -expand 1
    
    ###################################################################
    # cadre des options
    ###################################################################
    set fm .flfoptions
    labelframe $fm -labelanchor nw -text "Options"

    set f $fm.f1;frame $f
    # réduction
    label $f.lred -text [_ Reduction]
    eval tk_optionMenu $f.cbred  psnup::mreductions $reductions
    $f.cbred configure -width 4
    # rotation
    label $f.lrot -text [_ Rotation]
    eval tk_optionMenu $f.cbrot  psnup::mrotations $rotations
    $f.cbrot configure -width 4
    grid $f.lred -row 1 -column 1  -sticky e
    grid $f.cbred -row 1 -column 2
    grid $f.lrot -row 2 -column 1  -sticky e
    grid $f.cbrot -row 2 -column 2    
    pack $f -side left

    set f $fm.f2;frame $f
    # ligne
    checkbutton $f.cb -indicatoron 1 -variable psnup::ligne\
	-text [_ "Frame width"]
    bind $f.cb <1> "psnup::cb %W ligne"
    entry $f.eligne -width 3 -state disabled -relief flat
    eval tk_optionMenu $f.om psnup::munitligne $unit
    $f.om configure -width 3
    # auto-rotation
    checkbutton $f.cbautorota -indicatoron 1 -variable psnup::autorota\
	-text [_ "No auto rotation"]
    # en colonnes
    checkbutton $f.cbcolonnes -indicatoron 1 -variable psnup::col\
	-text [_ "In columns"]
    grid $f.cb -row 1 -column 1 -sticky w
    grid $f.eligne -row 1 -column 2
    grid $f.om -row 1 -column 3 -sticky w
    grid $f.cbautorota -row 2 -column 1 -sticky w
    grid $f.cbcolonnes -row 2 -column 3
    pack $f -side right
  

    ###################################################################
    # réduction centrée / Réarrangement / Livre
    ###################################################################
    set fm .flfreduccentree;frame $fm
    checkbutton $fm.cb -variable psnup::reduccentree \
        -command "psnup::ChangerEtatWidgets $fm" -padx 0 \
	-text [_ "Centered reduction"]
    checkbutton $fm.cb1 -variable psnup::rearrange \
        -command "psnup::ChangerEtatWidgetsR $fm" -padx 0 \
	-text [_ "File rearrangement"]
    checkbutton $fm.cb2 -variable psnup::livre\
	-text [_ "Produce a book"]
        #-command "psnup::ChangerEtatWidgetsL $fm" -padx 0 \
	
    grid $fm.cb -row 1 -column 1
    grid $fm.cb1 -row 1 -column 2
    grid $fm.cb2 -row 1 -column 3
    
    ###################################################################
    # sélection de pages
    ###################################################################
    set fm .flfselect
    labelframe $fm -text [_ "Pages selection"]
    checkbutton $fm.cb0 -variable psnup::selection  -text [_ "pages selection"]\
	-command "psnup::choixselection $fm" -state disabled
    foreach {i texte} \
	{1 {[_ "even pages"]} 2 {[_ "odd pages"]} 3 {[_ "disable parity"]}} {
	eval radiobutton $fm.cb$i -variable psnup::parite -value $i -text $texte \
	    -state disabled
    }
    entry $fm.e0 -width 10  -state disabled
    button $fm.b0 -text [_ info...] -command "psnup::infoselpages" -state disabled
    foreach i {0 1 2 3} {
	grid $fm.cb$i -row $i -column 1 -sticky w
    }
    grid $fm.e0 -row 0 -column 2
    grid $fm.b0 -row 0 -column 3 -sticky w

    checkbutton $fm.cb4 -variable psnup::ordre -text [_ "opposite order"]\
	-state disabled
    checkbutton $fm.cb5 -variable psnup::renum -text [_ "no renumbering"] \
	-state disabled
    grid $fm.cb4 -row 1 -column 3 -sticky w
    grid $fm.cb5 -row 2 -column 3 -sticky w
    ###################################################################
    # packs
    ###################################################################
    foreach f {flffichiers freunion maf flfoptions flfreduccentree flfselect} {
	if {$f=="freunion"} {pack .$f -pady 3;continue}
	pack .$f -padx 10 -pady 3 -fill x
    }

    # hmmmmm....
    canvas .moi  -relief groove -width 20 -height 18
    set mafonte {Times 14 bold}
    set logo {
	2 1 D {-anchor nw}
	4 2 C {-anchor nw  -font $mafonte -fill red}
    }
#	20 7 2 {}
#	24 8 k {}
#	28 8 + {}
#	32 7 3 {-fill red}

    foreach {x y t opt} $logo {
	eval .moi create text $x $y -text $t $opt
    }
    pack .moi -side right -padx 5
    bind .moi <1> {tk_messageBox -message \
		       [_ "Author: David Cobac (cobac@free.fr)"]\
		       -title information\ page-crunch -type ok}
    
    # le visualisateur de .ps
    label .v -text [_ "PS:"]
    entry .e -width 10 -bg grey80 -relief raised -justify right -bd 2
    .e insert end ${psnup::visuPS}
    pack .e -side right -padx 5
    pack .v -side right

    # le visualisateur de .pdf
    label .xpdf -text [_ "visu. PDF:"]
    entry .epdf -width 10 -bg grey80 -relief raised -justify right -bd 2
    .epdf insert end ${psnup::visuPDF}
    pack .epdf -side right -padx 5
    pack .xpdf -side right

    ###################################################################
    # cadre des boutons
    ###################################################################
    frame .bb -width 100
    button .bb.bOK -text [_ Quit] -width 4 -command {
	psnup::sauvegarde
	exit
    }
    button .bb.bvisu -text [_ See]  -width 4 -command psnup::Execute
    pack .bb.bOK -side left
    pack .bb.bvisu -side left

    pack .bb -expand 1  -side right
}

# psnup::ChangerEtatWidgets
#
# Args :
#     w    la frame contenant les checkboxes de sélection
#          des options de réduc / réarrangment / livre
# Res :
#    change l'état des widgets lorsqu'on (dés)active l'option
#    de simple réduction centrée

proc psnup::ChangerEtatWidgets {w} {
    # widgets de la frame en question
    foreach child [winfo children $w] {
        if {$child == "$w.cb"} continue
        if {!$psnup::reduccentree} {
            $child configure -state normal
        } else {
            $child configure -state disabled
        }
    }
    # les autres widgets ...
    set WidAModif {
	.freunion.l .freunion.cb
	.maf.flfformats.lentree
	.maf.flfformats.cbentree
	.flfoptions.f1.cbrot .flfoptions.f1.lrot
	.flfoptions.f2.cbautorota .flfoptions.f2.cbcolonnes
	.flfoptions.f2.cbcolonnes
    }
    lappend WidAModif [winfo children .maf.flfmarges]
    set i [join $WidAModif]
    if {!$psnup::reduccentree} {
	set etat normal
    } else {
	set etat disabled
    }
    foreach w $i {
	$w configure -state $etat
    }
}

# psnup::ChangerEtatWidgetsR
#
# Args :
#     w    la frame contenant les checkboxes de sélection
#          des options de réduc / réarrangment / livre
# Res :
#    change l'état des widgets lorsqu'on (dés)active l'option
#    de réarrangement

proc psnup::ChangerEtatWidgetsR {w} {
    # widgets de la frame en question
    foreach child [winfo children $w] {
        if {$child == "$w.cb1"} continue
        if {!$psnup::rearrange} {
            $child configure -state normal
        } else {
            $child configure -state disabled
        }
    }
    # les autres widgets ...
    foreach w {.flfoptions.f1 .flfoptions.f2 .freunion \
	 .maf.flfmarges} {
	lappend WidAModif [winfo children $w]
    }
    set i [join $WidAModif]
    if {!$psnup::rearrange} {
	set etat normal
	set etat2 disabled
    } else {
	set etat disabled
	set etat2 normal
    }
    foreach w $i {
	$w configure -state $etat
    }
    foreach w [winfo children .flfselect] {
	$w configure -state $etat2
    }
}

# psnup::ChangerEtatWidgetsL
#
# Args :
#     w    la frame contenant les checkboxes de sélection
#          des options de réduc / réarrangment / livre
# Res :
#    change l'état des widgets lorsqu'on (dés)active l'option
#    de livre

proc psnup::ChangerEtatWidgetsL {w} {
    # widgets de la frame en question
    foreach child [winfo children $w] {
        if {$child == "$w.cb2"} continue
        if {!$psnup::livre} {
            $child configure -state normal
        } else {
            $child configure -state disabled
        }
    }
    # les autres widgets ...
    set WidAModif {
	.freunion.l
	.freunion.cb
	.maf.flfformats.lentree
	.maf.flfformats.cbentree
	.flfoptions.f1.cbrot .flfoptions.f1.lrot
	.flfoptions.f2.cbautorota .flfoptions.f2.cbcolonnes
	.flfoptions.f2.cbcolonnes
    }
    lappend WidAModif [winfo children .maf.flfmarges]
    set i [join $WidAModif]
    if {!$psnup::livre} {
	set etat normal
    } else {
	set etat disabled
    }
    foreach w $i {
	$w configure -state $etat
    }
}

# psnup::ChoixFichier
#
# Args :
#     fen_bouton     la frame contenant les sélections de fichiers
#     opt (optionel) différencie le bouton out du bouton in...
#
# Res :
#    affiche et valide le choix des fichiers in et out

proc psnup::ChoixFichier { fen_bouton {opt ""}} {
    set types {
	{"PS et PDF" ".ps .PS .pdf .PDF"}
	{"PostScript" ".ps .PS"}
	{"Portable Document Format" ".pdf .PDF"}
	{"Tous"		*}
    }
    if {$opt=="S"} {
	set choix [tk_chooseDirectory]
	if {$choix!=""} {
	    $fen_bouton.eS delete 0 end
	    $fen_bouton.eS insert end $choix
	}
    } else {
	set choix [tk_getOpenFile -filetypes $types -parent $fen_bouton]
	if {$choix!=""} { 
	    set psnup::NomFichier $choix
	    $fen_bouton.e delete 0 end
	    $fen_bouton.e insert end $psnup::NomFichier
	    if {[string index $fen_bouton end]!="S"} {
		set psnup::NomFichierS [file rootname\
			 $psnup::NomFichier]_reduit[file extension\
							$psnup::NomFichier]
		${fen_bouton}.eS delete 0 end
		${fen_bouton}.eS insert end $psnup::NomFichierS
	    }
	    psnup::AfficheInfo $fen_bouton
	}
    }
}

# psnup::choixselection
#
# Args :
#     w  la frame contenant l'entrée à modifier
#          
# Res :
#    changement d'état de l'entrée des sélections de page
#    dans l'option sélection de pages

proc psnup::choixselection {w} {
    if $psnup::selection {
	$w.e0 configure -relief sunken -bg white -state normal
    } else {
	$w.e0 configure -relief groove -state disabled 
    }
	
}

# psnup::cb
#
# Args :
#    cb   checkbutton sur lequel on a appuyé
#    nom  nom de la variable associée (non qualifié)
#
# Res :
#    change l'état des entrées associées aux cbs (pas à tous !) 

proc psnup::cb { cb nom } {
    set bool psnup::$nom
    if ![set $bool] {
	set etat normal
	set relief sunken
    } else {
	set etat disabled
	set relief flat
    }
    [winfo parent $cb].e${nom} configure -state $etat -relief $relief
}

# psnup::AfficheInfo
#
# Args :
#    fen  frame de l'étiquette des infos
#
# Res :
#    affichage des infos du fichier in

proc psnup::AfficheInfo { fen } {
    global tcl_platform
    if {[file extension ${psnup::NomFichier}]==".pdf" ||
	[file extension ${psnup::NomFichier}]==".PDF"} {
	if {$tcl_platform(platform)=="unix"} {
	    set infos [psnup::InfosPDF]
	    set n [lindex $infos 0]
	    set dim [lrange $infos 1 2]
	    foreach d $dim {
		if [catch {
		    lappend bboxcm [format %.01f [expr {$d*$psnup::pt/10}]]
		}] {
		    set bboxcm [_ "no available dimensions!"]
		}
	    }
	    $fen.lI2 configure -relief groove \
		-text [format [_ "%s page(s) and in cm: %s"] $n $bboxcm] 
	    return
	}
    }
    set f [Ouverture $psnup::NomFichier]
    set nbpages [psnup::LectureNbPages $f]\ page(s)
    set bbox [lrange [psnup::LectureBoundingBox $f] 2 3]
    foreach w $bbox {
	if [catch {
	    lappend bboxcm [format %.01f [expr {$w*$psnup::pt/10}]]
	}] {
	    set bboxcm [_ "no available dimensions!"]
	}
    }
    close $f
    $fen.lI2 configure -relief groove \
	-text [format [_ "%s and in cm: %s"] $nbpages $bboxcm] 
 }

# psnup::ProductionCommandePSNUP
#
# Args :
#
# Res :
#    réalisation des options de la commande psnup

proc psnup::ProductionCommandePSNUP { } {
    
    set psnup::ListeOptions ""
    
    set f2 .maf.flfformats
    set f3 .maf.flfmarges
    set f4 .flfoptions
    
    # lecture optionMenu avec prefixe
    foreach {opt type} {sortie p entree P} {
	lappend psnup::ListeOptions -${type}[set psnup::m$opt] 
    }
    
    # lecture optionMenu avec changement
    # reduction
    if {$psnup::mreductions!="auto"} {
	lappend psnup::ListeOptions -s$psnup::mreductions 
    }
    # rotation
    if {$psnup::mrotations=="+90"} {
	lappend psnup::ListeOptions -r 
    } elseif {$psnup::mrotations=="-90"} {
	lappend psnup::ListeOptions -l 
    }

    # auto-rotation
    if $psnup::autorota {
	lappend psnup::ListeOptions -f
    }
    # placement en colonnes
    if $psnup::col {
	lappend psnup::ListeOptions -c
    }
    # lecture checkbox
    # marges (global)
    if $psnup::marges {
	set dim [$f3.emarges get]
	lappend psnup::ListeOptions -m${dim}${psnup::munitmarges} 
    }
    # bordure (marge sur chaque page)
    if $psnup::bordure {
	set dim [$f3.ebordure get]
	lappend psnup::ListeOptions -b${dim}${psnup::munitbordure} 
    }
    #ligne
    if $psnup::ligne {
	set dim [$f4.f2.eligne get]
	lappend psnup::ListeOptions -d${dim}${psnup::munitligne} 
    }
    # lecture directe de l'option
    foreach opt {reunion} {
	lappend psnup::ListeOptions -${psnup::mreunions} 
    }
}

# psnup::ProductionCommandeRea
#
# Args :
#
# Res :
#    construction de la commande psselect

proc psnup::ProductionCommandeRea { } {
    set f .flfselect
    set psnup::ListeOptions ""
    if $psnup::renum {lappend psnup::ListeOptions -q}
    if {$psnup::parite==1} {
	lappend psnup::ListeOptions -e
    } elseif {$psnup::parite==2} {
	lappend psnup::ListeOptions -o
    }
    if $psnup::ordre {lappend psnup::ListeOptions -r}
    if $psnup::selection {
	lappend psnup::ListeOptions -p[$f.e0 get]
    }
}

# psnup::ProductionCommandeReduc
#
# Args :
#
# Res :
#    construction de la réduction centrée

proc psnup::ProductionCommandeReduc { } {
    if {[file extension ${psnup::NomFichier}]!=".pdf" &&
	[file extension ${psnup::NomFichier}]!=".PDF"} {
	set f [psnup::Ouverture ${psnup::NomFichier}]
    } else {
	set f [psnup::Ouverture ${psnup::NomFichierPS}]
    }
    set dim [psnup::LectureBoundingBox $f]

    psnup::Fermeture $f
    set dimx [lindex $dim 2]
    set dimy [lindex $dim 3]
    set psnup::ListeOptions ""
    if {$psnup::mreductions=="auto"} "set psnup::mreductions 0.7"
    set newdimx [expr {$dimx*$psnup::mreductions}]
    set newdimy [expr {$dimy*$psnup::mreductions}]
    set xoffset [expr {($dimx-$newdimx)/2}]
    set yoffset [expr {($dimy-$newdimy)/2}]
    set psnup::ajout ""
    if $psnup::ligne {
	set dim [.flfoptions.f2.eligne get]
	set psnup::ajout -d${dim}${psnup::munitligne} 
    }
    lappend psnup::ListeOptions\
	"1:0@${psnup::mreductions}(${xoffset}pt,${yoffset}pt)"
}

# psnup::ProductionCommandeBook
#
# Args :
#
# Res :
#    construction de la signature pour psbook

proc psnup::ProductionCommandeBook { } {
    set psnup::ListeOptions ""
    set nb ${psnup::mreunions}
    if {${psnup::mreunions}%2!=0} {
	set nb [expr {${psnup::mreunions}+1}]
    }
    set sign [expr {2*$nb}]
    lappend psnup::ListeOptions -s$sign
}


# psnup::ExecutePSNUP
#
# Args :
#   fic_ps_in   fichier postscript d'entrée
#   fic_ps_out  fichier postscript de sortie
#
# Res :
#   execution de psnup / affichage de la sortie

proc psnup::ExecutePSNUP { fic_ps_in fic_ps_out } {
    set args $psnup::ListeOptions
    set macom "psnup [join $args] \"$fic_ps_in\" \"$fic_ps_out\""
    catch {eval exec $macom} sortie
    tk_messageBox -default ok -message $sortie -parent .\
	-title ${psnup::psnupversion}
}

# psnup::ExecuteReduc
#
# Args :
#   fic_ps_in   fichier postscript d'entrée
#   fic_ps_out  fichier postscript de sortie
#
# Res :
#   execution de pstops / affichage de la sortie

proc psnup::ExecuteReduc { fic_ps_in fic_ps_out } {
    set com "pstops ${psnup::ajout} \"${psnup::ListeOptions}\"\
 \"$fic_ps_in\" \"$fic_ps_out\""
    catch {eval exec $com} sortie
    tk_messageBox -default ok -message $sortie -parent .\
	-title ${psnup::pstopsversion}
}

# psnup::ExecuteRea
#
# Args :
#   fic_ps_in   fichier postscript d'entrée
#   fic_ps_out  fichier postscript de sortie
#
# Res :
#   execution de psselect / affichage de la sortie

proc psnup::ExecuteRea { fic_ps_in fic_ps_out } {
    set com "psselect $psnup::ListeOptions \"$fic_ps_in\" \
 \"$fic_ps_out\""
    catch {eval exec $com} sortie
    tk_messageBox -default ok -message $sortie -parent .\
	-title ${psnup::psselectversion}
}

# psnup::ExecuteBook
#
# Args :
#   fic_ps_in   fichier postscript d'entrée
#   fic_ps_out  fichier postscript de sortie
#
# Res :
#   execution de psbook 

proc psnup::ExecuteBook { fic_ps_in fic_ps_out } {
#    set com "psbook $psnup::ListeOptions \"$fic_ps_in\" | psnup -2 >\
# \"$fic_ps_out\""
    set com "psbook \"$fic_ps_in\" | psnup -2 >\
# \"$fic_ps_out\""
#    puts $com
    catch {eval exec $com} sortie
#    tk_messageBox -default ok -message $sortie -parent .\
#			-title ${psnup::psselectversion}
}

# psnup::Execute
#
# Args :
#   flag  (optionnel) indicateur de sortie du logiciel
#
# Res :
#   callback du bouton "visualiser" 

proc psnup::Execute { {flag 1} } {
    set psnup::visuPS [.e get]
    set psnup::visuPDF [.epdf get]
    if {$psnup::NomFichier==""} {
	# on verifie que l'utilisateur ne l'a pas rempli a la main :
	set psnup::NomFichier [string trim [.flffichiers.e get]]
	if {$psnup::NomFichier==""} return
    }
    set psnup::NomFichierS [.flffichiers.eS get]
    if {$psnup::NomFichierS==""} "set psnup::NomFichierS temporaire.ps"

    set choix PSNUP
    if $psnup::reduccentree {
	set choix Reduc
    } elseif $psnup::rearrange {
	set choix Rea
    } elseif $psnup::livre {
	set choix Book
    }

    psnup::pdfversps
    
    if $psnup::livre {
	eval psnup::ProductionCommande$choix
	eval psnup::Execute$choix [list ${psnup::NomFichierPS}] temporaire.ps
	eval psnup::ProductionCommandePSNUP
	eval psnup::ExecutePSNUP temporaire.ps [list ${psnup::NomFichierPSS}]
    } else {
	eval psnup::ProductionCommande$choix
	eval psnup::Execute$choix [list ${psnup::NomFichierPS}]\
	    [list ${psnup::NomFichierPSS}]
    }
    psnup::psverspdf
    psnup::Visu 
    
    set psnup::ListeOptions ""
    psnup::Nettoyage
    if !$flag "psnup::partir"
}

# psnup::pdfversps
#
# Args :
#
# Res :
#   La procédure initialise deux nouvelles variables
#   identique aux noms des fichiers in et out dans le cas
#   de ps à traiter sinon crée des fichiers temporaires ps.

proc psnup::pdfversps { } {
    global tcl_platform
    variable mentree
    if {[file extension ${psnup::NomFichier}]!=".pdf"  &&
	[file extension ${psnup::NomFichier}]!=".PDF"} {
	set psnup::NomFichierPS $psnup::NomFichier
	set psnup::NomFichierPSS $psnup::NomFichierS
	return
    }
    set psnup::NomFichierPS \
	[file rootname ${psnup::NomFichier}]_temporaireE.ps
    set psnup::NomFichierPSS \
	[file rootname ${psnup::NomFichier}]_temporaireS.ps

    if {$tcl_platform(platform)=="windows"} {
	set opt "-dNOPAUSE -dBATCH -dSAFER \
-sPAPERSIZE ${psnup::mentree} -sDEVICE=pswrite "
	set fic_in [string map {\  \\\ } ${psnup::NomFichier}]
	set fic_out [string map {\  \\\ } ${psnup::NomFichierPS}]
	catch {eval exec gswin32c.exe -sOUTPUTFILE=${fic_out} \
		   $opt ${fic_in}} sortie
    } else {
	set com ${psnup::ComPDFtoPS}
	catch {eval exec [list $com] -paper match\
	       [list ${psnup::NomFichier}]\
	       [list ${psnup::NomFichierPS}]} sortie
    }
}

# psnup::psverspdf
#
# Args :
#
# Res :
#   si on traite un pdf, cela convertit la sortie de
#   psnup/psselect/pstops/psbook en un pdf

proc psnup::psverspdf { } {
    global tcl_platform
    variable msortie
    if {[file extension ${psnup::NomFichier}]!=".pdf"  &&
	[file extension ${psnup::NomFichier}]!=".PDF"} {
	return
    }
    if {$tcl_platform(platform)=="windows"} {
	set opt "-dNOPAUSE -dBATCH -dSAFER \
-sPAPERSIZE ${psnup::msortie} -sDEVICE=pswrite "
	set fic_in [string map {\  \\\ } ${psnup::NomFichierPSS}]
	set fic_out [string map {\  \\\ } ${psnup::NomFichierS}]
	catch {eval exec gswin32c.exe -sOUTPUTFILE=${fic_out} $opt ${fic_in}} sortie
    } else {
	set com ${psnup::ComPStoPDF}
	catch {eval exec [list $com] -sPAPERSIZE=$msortie\
		   [list ${psnup::NomFichierPSS}]\
		   [list ${psnup::NomFichierS}]} sortie
    }
}

#  psnup::Visu
#
# Args :
#
# Res :
#   affiche la visualisation de la sortie

proc psnup::Visu {} {
    if {[file extension ${psnup::NomFichier}]!=".pdf"  &&
	[file extension ${psnup::NomFichier}]!=".PDF"} {
	set psnup::visu ${psnup::visuPS}
    } else {
	set psnup::visu ${psnup::visuPDF}
    }
    set opt ""
    if {$psnup::visu=="gv"} {
	# dommage de devoir passer par une erreur...
	if {[catch {exec gv --version}]} {
	    set opt "-media $psnup::msortie "
	} else {
	    set opt "--media=$psnup::msortie "
	}
    }
    eval exec [list ${psnup::visu}] $opt [list $psnup::NomFichierS]
}

# psnup::Ouverture
#
# Args :
#   nom  nom du fichier à traiter
#
# Res :
#   ouverture d'un chan vers un fichier
#   retour l'id du fichier ouvert

proc psnup::Ouverture { nom } {
	return [open $nom r]
}


# psnup::Fermeture
#
# Args :
#   id_fichier  identifiant du fichier à fermer
#
# Res :
#   fermeture d'un chan vers un fichier

proc psnup::Fermeture { id_fichier } {
    close $id_fichier
}

# psnup::LectureNbPages
#
# Args :
#   id_fichier  identifiant du fichier ps
#
# Res :
#   retourne le nombre de pages lues dans le fichier ps

proc psnup::LectureNbPages { id_fichier } {
    seek $id_fichier 0 start
    while {![eof $id_fichier]} {
	gets $id_fichier ligne
	if {[regexp {%%Pages:\s*([0-9]*)\s*.*} $ligne A nb]} {
	    return $nb
	}
    }
}

# psnup::LectureBoundingBox
#
# Args :
#   id_fichier  identifiant du fichier ps
#
# Res :
#   lit la bbox lisible du fichier ps et renvoie
#   une liste des quatre valeurs normalement lues

proc psnup::LectureBoundingBox { id_fichier } {
    seek $id_fichier 0 start
    while {![eof $id_fichier]} {
	gets $id_fichier ligne
	if {[regexp {%%BoundingBox:\s*(.*)} $ligne A dim]} {
	    return $dim
	} elseif {[regexp {%%DocumentMedia:\s[a-zA-Z]*\s(.*)} $ligne A dim]} {
	    return [join "0 0 [lrange $dim 0 1]"]
	}
    }
    # par défaut....du A4
    return [list absence de dimension !]
}


proc psnup::InfosPDF {} {
    set com "pdfinfo $psnup::NomFichier | grep Page.*:"
    catch {eval exec $com} sortie
    set res [split $sortie \n]
    regexp {Pages:\s*([0-9]*)} [lindex $res 0] A nb
    regexp {Page size:\s*([0-9]*) x ([0-9]*)} [lindex $res 1] A x y
    if [catch {set liste [list $nb $x $y]}] {
	set liste {- - -}
    }
    return $liste
}

# psnup::Nettoyage
#
# Args :
#
# Res :
#   Suppression de tout ce qui est temporaire

proc psnup::Nettoyage { } {
    if {[file extension ${psnup::NomFichier}]!=".pdf"} {
	file delete temporaire.ps
	return
    }
    file delete ${psnup::NomFichierPS} 
    file delete ${psnup::NomFichierPSS}
}

# psnup::partir
#
# Args :
#
# Res :
#   Sauvegarde config. et sortie du logiciel

proc psnup::partir {} {
    psnup::sauvegarde
    exit
}

# psnup::sauvegarde
#
# Args :
#
# Res :
#   Écriture du fichier de config.

proc psnup::sauvegarde {} {
    global tcl_platform env

    set rep $env(HOME)
    if {$tcl_platform(platform)=="unix"} {
	set fic "$rep/.pcrunch"
    } elseif {$tcl_platform(platform)=="windows"} {
	set fic [file join $rep pcrunchrc]
    } else {
	set fic "~/.pcrunch"
    }

    if [catch {set f [open "$fic" w+]}] "return"

    set psnup::visuPS [.e get]
    set psnup::visuPDF [.epdf get]
    
    puts $f "# fichier créé par le/un front-end de psnup : page-crunch
# Vous pouvez régler ici les diverses commandes utilisées par page-crunch
# en modifiant les valeurs entre parenthèses.\n
# Conversion pdf vers ps :
set psnup::ComPDFtoPS \{$psnup::ComPDFtoPS\}
# Conversion pdf vers ps pour windows
set psnup::ComPDFtoPSW \{$psnup::ComPDFtoPSW\}
# Conversion ps vers pdf :
set psnup::ComPStoPDF \{$psnup::ComPStoPDF\}
# Visualisateur ps (réglable aussi via l'interface graphique)
set psnup::visuPS \{$psnup::visuPS\}
# Visualisateur pdf (réglable aussi via l'interface graphique)
set psnup::visuPDF \{$psnup::visuPDF\}"
    close $f

}

# psnup::ouvrirPerso
#
# Args :
#
# Res :
#   lecture du fichier de config. pour fixer les variables persos

proc psnup::ouvrirPerso {} {
    global tcl_platform env

    set rep $env(HOME)
    if {$tcl_platform(platform)=="unix"} {
	set fic "$rep/.pcrunch"
    } elseif {$tcl_platform(platform)=="windows"} {
	set fic [file join $rep pcrunchrc]
    } else {
	set fic "~/.pcrunch"
    }

    if [catch {source $fic}] "return"
}

# psnup::infoselpages
#
# Args :
#
# Res :
#   Affiche une info sur la sélection des pages avec
#   une toplevel "grabée"

proc psnup::infoselpages {} {
    set i .info;toplevel $i
    text $i.t -width 50 -height 8 -relief groove
    $i.t insert end [_ "To select pages, you can use:
    * one by one: 1,3,7
    * from first to 7th: 1-7
    * from third to last: 3-
    * second from the end: _2
    * combination of what preceeds with
      comma separations"]
    $i.t configure -state disabled
    button $i.b -text ok -command "destroy $i" -width 10
    pack $i.t -side top
    pack $i.b -side bottom
    grab $i
}


#############################################################################
####################### LANCEMENT DE page-crunch ############################
#############################################################################
proc psnup::debug {commande} {
    puts $commande
}

namespace import psnup::*
set nom [lindex $argv 0]

set psnup::NomFichier $nom
set psnup::NomFichierS $nom
if {$nom!=""}  {
    set psnup::NomFichierS [file rootname $nom]_reduit[file extension $nom]
}
wm resizable . false false
wm title . "page-crunch (v. ${psnup::version})"
bind . <Control-q> "psnup::partir"

tk_setPalette grey60

ouvrirPerso
gui
