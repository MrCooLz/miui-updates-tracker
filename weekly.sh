#Cleanup
rm raw_out compare changes updates dl_links 2> /dev/null

#Download
curl -H "PRIVATE-TOKEN: $token" 'https://gitlab.com/api/v4/projects/7746867/repository/files/getversion.sh/raw?ref=master' -o getversion.sh && chmod +x getversion.sh
wget -q https://github.com/yshalsager/telegram.sh/raw/master/telegram && chmod +x telegram

#Check if db exist
if [ -e weekly_db ]
then
    mv weekly_db weekly_db_old
else
    echo "DB not found!"
fi

#Fetch
echo Fetching updates:
cat devices | while read device; do
	codename=$(echo $device | cut -d , -f1)
	android=$(echo $device | cut -d , -f3)
	url=`./getversion.sh $codename X $android`
	tmpname=$(echo $device | cut -d , -f1 | sed 's/_/-/g')
	name=$(echo $device | cut -d '"' -f2)
	echo $tmpname"="$url \"$name\" >> raw_out
done
sed -i 's/param error/none/g' ./raw_out
cat raw_out | sort | sed 's/http.*miui_//' | cut -d _ -f1,2 | cut -d ' ' -f1 | sed 's/-/_/g' > weekly_db

#Compare
echo Comparing:
cat weekly_db | while read rom; do
	codename=$(echo $rom | cut -d = -f1)
	new=`cat weekly_db | grep $codename | cut -d = -f2`
	old=`cat weekly_db_old | grep $codename | cut -d = -f2`
	diff <(echo "$old") <(echo "$new") | grep ^"<\|>" >> compare
done
awk '!seen[$0]++' compare > changes

#Info
if [ -s changes ]
then
	echo "Here's the new updates!"
	cat changes | grep ">" | cut -d ">" -f2 | sed 's/ //g' 2>&1 | tee updates
else
    echo "No changes found!"
fi

#Downloads
if [ -s updates ]
then
    echo "Download Links!"
	for rom in `cat updates | cut -d = -f2`; do cat raw_out | grep $rom ; done 2>&1 | tee dl_links
else
    echo "No new updates!"
fi

#Telegram
cat dl_links | while read line; do
	name=$(echo $line | cut -d '"' -f2)
	model=$(echo $line | cut -d = -f2 | cut -d / -f5 | cut -d _ -f2)
	codename=$(echo $line | cut -d = -f1)
	version=$(echo $line | cut -d = -f2 | cut -d / -f4)
	android=$(echo $line | cut -d = -f2 | cut -d / -f5 | cut -d _ -f5 | cut -d . -f1,2)
	link=$(echo $line | cut -d = -f2 | cut -d ' ' -f1)
	size=$(wget --spider $link --server-response -O - 2>&1 | sed -ne '/Length:/{s/*. //;p}' | tail -1 | cut -d ' ' -f3)
	./telegram -t $bottoken -c $chat -M "New weekly update available!
	*Device*: $name
	*Product*: $model
	*Codename*: $codename
	*Version*: $version
	*Android*: $android
	*Filesize*: $size
	*Download Link*: [Here]($link)
	@MIUIUpdatesTracker | @XiaomiFirmwareUpdater"
done

#Push
git add weekly_db ; git commit --author="$gituser <$gitmail>" -m "Sync: $(date +%d.%m.%Y)"
git push -q https://$GIT_OAUTH_TOKEN_XFU@github.com/XiaomiFirmwareUpdater/miui-updates-tracker.git HEAD:weekly