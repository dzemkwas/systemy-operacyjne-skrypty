#!/bin/sh

if [ $# -ne 2 ]
then
	echo "Niepoprawna liczba argumentow"
	echo "Użycie skryptu: $0 <katalog> <plik-wyjsciowy.gpx>"
	exit 1
fi

if ! exiftool -ver &>/dev/null
then
	echo "Do funkcjonowania programu wymagane jest narzędzie exiftool"
	exit 1
fi

DIR=$1
OUT=$2
MAX_TIME=3600 #godzina w sekundach

PHOTOS=0
TOTAL_PHOTOS=0
PATHS=0

#tworzenie tmp pliku bo go nie trzeba czyscic manualnie chyba
TMP_FILE=$(mktemp)
declare -a FILE_NAMES

echo "Przeszukiwanie katalogu $DIR"
for file in $(find ~+ $(realpath $DIR) -iname '*.jpg')
do
	((TOTAL_PHOTOS++))
	#sekcje musza byc oddzielane znakiem | bo nie moze on wystepowac w nazwach sciezek (chyba)
	TMP=$(exiftool -f -s3 -d '%Y-%m-%dT%H:%M:%SZ' -c '%.5f' -p '$CreateDate|$GPSLatitude#|$GPSLongitude#' $file)
	TMP+="|$file"
	if [[ ! $TMP =~ '-|-' ]]
	then
		((PHOTOS++))
		echo $TMP >> $TMP_FILE
	fi
done

LAST=0
TRK_OUT="<trk><trkseg>"
RTE_OUT="<rte>"
INDEX=0
PATH_LENGTH=0
for photo in $(cat $TMP_FILE | sort)
do
	#petla tworząca plik gpx
	FILE_NAME=$(echo $photo | cut -d '|' -f 4)
	DATE=$(echo $photo | cut -d '|' -f 1)
	DATE_UNIX=$(date -d $DATE +%s)
	LAT=$(echo $photo | cut -d '|' -f 2)
	LON=$(echo $photo | cut -d '|' -f 3)
	((PATH_LENGTH++))
	

	#jesli czas pomiedzy poprzednim a obecnym zdjeciem wynosi godzine(moze byc wiecej lub mniej trzeba zmienic zmienna $MAX_TIME)
	if [[ $(($DATE_UNIX - $LAST)) -gt $MAX_TIME && $LAST -ne 0 ]]
	then
		if [[ $PATH_LENGTH -ge 2 ]]
		then
			((PATHS++))
		fi
		PATH_LENGTH=0
		TRK_OUT+="</trkseg></trk><trk><trkseg>"
		RTE_OUT+="</rte><rte>"
	fi
	LAST=$DATE_UNIX
	TRK_OUT+="<trkpt lat='$LAT' lon='$LON'><time>$DATE</time></trkpt>"
	RTE_OUT+="<rtept lat='$LAT' lon='$LON'><link href='file://$FILE_NAME'><text>$FILE_NAME</text><type>image/jpeg</type></link><desc>&lt;img width=128 height=128 src='$FILE_NAME'&gt;</desc></rtept>"



done
TRK_OUT+="</trkseg></trk>"
RTE_OUT+="</rte>"
if [[ ! $PHOTOS -eq 0 ]]
then
	{
		echo "<gpx version='1.1'>"
		echo $TRK_OUT
		echo $RTE_OUT
		echo "</gpx>"
	} > $OUT
fi
echo "----------Wyniki----------"
echo "Ilość wszystkich zdjęć: $TOTAL_PHOTOS"
echo "Ilość zdjęć z tagami: $PHOTOS"
echo "Ilośc wygenerowanych ścieżek: $PATHS"
