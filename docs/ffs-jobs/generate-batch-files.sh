#!/bin/bash
# Génère 20 fichiers .ffs_batch à partir du template

set -eu

JOBS_DIR="/Volumes/logousb/SSD/Projects/NAS-logo/Docs/ffs-jobs"
mkdir -p "$JOBS_DIR"

# Liste des jobs (numéro|source|destination|nom)
JOBS=(
  "01|/Volumes/NAS-LOGO-DATA/_done/google-takeout-sample|/Volumes/Expansion12/sauvetmpo25mai/_done/google-takeout-sample|google-takeout-sample"
  "02|/Volumes/NAS-LOGO-DATA/_done/import16mai|/Volumes/Expansion12/sauvetmpo25mai/_done/import16mai|import16mai"
  "03|/Volumes/NAS-LOGO-DATA/_done/NewAppPhoto29Avril|/Volumes/Expansion12/sauvetmpo25mai/_done/NewAppPhoto29Avril|NewAppPhoto29Avril"
  "04|/Volumes/NAS-LOGO-DATA/_done/PhotoAvant2015|/Volumes/Expansion12/sauvetmpo25mai/_done/PhotoAvant2015|PhotoAvant2015"
  "05|/Volumes/NAS-LOGO-DATA/_done/scan-report|/Volumes/Expansion12/sauvetmpo25mai/_done/scan-report|scan-report"
  "06|/Volumes/NAS-LOGO-DATA/_done/ssd-immich-upload-old|/Volumes/Expansion12/sauvetmpo25mai/_done/ssd-immich-upload-old|ssd-immich-upload-old"
  "07|/Volumes/NAS-LOGO-DATA/_done/ssd-imports-2015-2018|/Volumes/Expansion12/sauvetmpo25mai/_done/ssd-imports-2015-2018|ssd-imports-2015-2018"
  "08|/Volumes/NAS-LOGO-DATA/_done/takeout-drive|/Volumes/Expansion12/sauvetmpo25mai/_done/takeout-drive|takeout-drive"
  "09|/Volumes/NAS-LOGO-DATA/_done/toshiba-1-photoslibrary|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-1-photoslibrary|toshiba-1-photoslibrary"
  "10|/Volumes/NAS-LOGO-DATA/_done/toshiba-a-classer2|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-a-classer2|toshiba-a-classer2"
  "11|/Volumes/NAS-LOGO-DATA/_done/toshiba-photos-videos-famille|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-photos-videos-famille|toshiba-photos-videos-famille"
  "12|/Volumes/NAS-LOGO-DATA/_done/toshiba-sauvegarde-20150319|/Volumes/Expansion12/sauvetmpo25mai/_done/toshiba-sauvegarde-20150319|toshiba-sauvegarde-20150319"
  "13|/Volumes/NAS-LOGO-DATA/_done/wd-pix-macos-photoslibrary|/Volumes/Expansion12/sauvetmpo25mai/_done/wd-pix-macos-photoslibrary|wd-pix-macos-photoslibrary"
  "14|/Volumes/NAS-LOGO-DATA/_done/wd-videos-famille-lot1|/Volumes/Expansion12/sauvetmpo25mai/_done/wd-videos-famille-lot1|wd-videos-famille-lot1"
  "15|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/SauvAvril2026|/Volumes/Expansion12/sauvetmpo25mai/SAUVAVRIL2026|SauvAvril2026"
  "16|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/Sauv Icloud|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/Sauv Icloud|Sauv-Icloud"
  "17|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/videos Perso Familles Voyage|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/videos Perso Familles Voyage|videos-Perso-Familles-Voyage"
  "18|/Volumes/NAS-LOGO-DATA/AFAIRE+tard/photos-toshiba-copy|/Volumes/Expansion12/sauvetmpo25mai/AFAIRE+tard/photos-toshiba-copy|photos-toshiba-copy"
  "19|/Volumes/NAS-LOGO-DATA/NAS-LOGO-VOLUME/personnes|/Volumes/Expansion12/backups/NAS/personnes|personnes"
  "20|/Volumes/NAS-LOGO-DATA/_done/takeout-extracted|/Volumes/Expansion12/sauvetmpo25mai/_done/takeout-extracted|takeout-extracted"
)

# Template .ffs_batch (mode batch, sync auto, fenêtre auto-close)
generate_batch() {
  local src="$1"
  local dst="$2"
  local out="$3"

  cat > "$out" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<FreeFileSync XmlType="BATCH" XmlFormat="23">
    <Notes/>
    <Batch>
        <ProgressDialog Minimized="false" AutoClose="true"/>
        <ErrorDialog>Show</ErrorDialog>
        <PostSyncAction>None</PostSyncAction>
    </Batch>
    <Compare>
        <Variant>TimeAndSize</Variant>
        <Symlinks>Exclude</Symlinks>
        <IgnoreTimeShift/>
    </Compare>
    <Synchronize>
        <Changes>
            <Left Create="right" Update="right" Delete="right"/>
            <Right Create="left" Update="left" Delete="left"/>
        </Changes>
        <DeletionPolicy>Permanent</DeletionPolicy>
        <VersioningFolder Style="Replace"/>
    </Synchronize>
    <Filter>
        <Include>
            <Item>*</Item>
        </Include>
        <Exclude>
            <Item>*\._*</Item>
            <Item>*\.DS_Store</Item>
            <Item>*\.TemporaryItems</Item>
            <Item>*\.Spotlight-V100</Item>
            <Item>*\.fseventsd</Item>
            <Item>*\.DocumentRevisions-V100</Item>
            <Item>*\.Trashes</Item>
        </Exclude>
        <SizeMin Unit="None">0</SizeMin>
        <SizeMax Unit="None">0</SizeMax>
        <TimeSpan Type="None">0</TimeSpan>
    </Filter>
    <FolderPairs>
        <Pair>
            <Left>${src}</Left>
            <Right>${dst}</Right>
        </Pair>
    </FolderPairs>
    <Errors Ignore="false" Retry="0" Delay="5"/>
    <PostSyncCommand Condition="Completion"/>
    <LogFolder/>
    <EmailNotification Condition="Always"/>
    <GridViewType>Action</GridViewType>
</FreeFileSync>
EOF
}

for job in "${JOBS[@]}"; do
  IFS='|' read -r num src dst name <<< "$job"
  out="$JOBS_DIR/${num}-${name}.ffs_batch"
  generate_batch "$src" "$dst" "$out"
  echo "✅ Créé : $out"
done

echo ""
echo "🎉 20 fichiers .ffs_batch créés dans $JOBS_DIR"
ls -la "$JOBS_DIR"/*.ffs_batch | head -5
