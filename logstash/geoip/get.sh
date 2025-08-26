#!/bin/bash

# ASN და GeoIP ბაზების გადმოწერა
mkdir -p logstash/geoip

cd logstash/geoip

# MaxMind GeoLite2 ბაზები (უფასო)
echo "Downloading GeoLite2 databases..."

# City database
wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${jxF66V}&suffix=tar.gz" -O GeoLite2-City.tar.gz

# Country database  
wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=${jxF66V}&suffix=tar.gz" -O GeoLite2-Country.tar.gz

# ASN database
wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-ASN&license_key=${jxF66V}&suffix=tar.gz" -O GeoLite2-ASN.tar.gz

# გაშალე არქივები
echo "Extracting databases..."
for file in *.tar.gz; do
    tar -xzf "$file" --strip-components=1
    rm "$file"
done

echo "GeoIP databases downloaded successfully!"
echo "Files available:"
ls -la *.mmdb
