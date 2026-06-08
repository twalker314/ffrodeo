#!/bin/zsh
srcdirec="${HOME}/iCloudDrive/a.u.d.i.o/24000/24000"
dstdirec="${HOME}/Downloads/layouts"
builddir="${PWD}-build"
test -d  "${builddir}" || return 1
test -d  "${srcdirec}" || return 1
for i in "${srcdirec}"/*.*
do
	mkdir -p -- "${dstdirec}"
	touch -- "${dstdirec}/${i:t}-ffmpeg1"
	rm -f -- "${dstdirec}/${i:t}-ffmpeg"*
done
make -C  "${builddir}"
for i in "${srcdirec}"/*.*
do
	"${builddir}/ffmpeg" -v error -i "$i" -c pcm_s16be \
		-f aiff -y "${dstdirec}/${i:t}-ffmpeg.aif"    ||
	{
		local return="${?}"
		echo "Error: ${i:t}-ffmpeg.aif" 1>&2
		return "${return}"
	}
	"${builddir}/ffmpeg" -v error -i "$i" -c pcm_s16le \
		-f caf -y "${dstdirec}/${i:t}-ffmpeg.caf"     ||
	{
		local return="${?}"
		echo "Error: ${i:t}-ffmpeg.caf" 1>&2
		return "${return}"
	}
	"${builddir}/ffmpeg" -v error -i "$i" -c pcm_s16le \
		-f mov -y "${dstdirec}/${i:t}-ffmpeg.mov"     ||
	{
		local return="${?}"
		echo "Error: ${i:t}-ffmpeg.mov" 1>&2
		return "${return}"
	}
done
{
	decorate="${(l:99::-:)}"
	printf "${decorate}\n"
	for i in "${srcdirec}"/*.*
	do
		multichannel=1
		test "${i[-9,-1]}" = "MONO.FLAC" && multichannel=0
		test "${i[-11,-1]}" = "STEREO.FLAC" && multichannel=0
		afinfoa=$(afinfo "${dstdirec}/${i:t}-ffmpeg.aif" | grep -o -e "Channel layout: .*" -e "no channel layout.")
		afinfoc=$(afinfo "${dstdirec}/${i:t}-ffmpeg.caf" | grep -o -e "Channel layout: .*" -e "no channel layout.")
		afinfom=$(afinfo "${dstdirec}/${i:t}-ffmpeg.mov" | grep -o -e "Channel layout: .*" -e "no channel layout.")
		srcinfo=$("${builddir}/ffprobe" -i "${i}"                           2>&1 | grep -o "[[:digit:]]*0 Hz.*s16")
		aifinfo=$("${builddir}/ffprobe" -i "${dstdirec}/${i:t}-ffmpeg.aif"  2>&1 | grep -o "[[:digit:]]*0 Hz.*s16")
		cafinfo=$("${builddir}/ffprobe" -i "${dstdirec}/${i:t}-ffmpeg.caf"  2>&1 | grep -o "[[:digit:]]*0 Hz.*s16")
		movinfo=$("${builddir}/ffprobe" -i "${dstdirec}/${i:t}-ffmpeg.mov"  2>&1 | grep -o "[[:digit:]]*0 Hz.*s16")
		test 0 -ne "${multichannel}" &&
		{
			test "${afinfoa}" != "${afinfoc}" && { echo "Error: ${i:t}-ffmpeg.aif ${afinfoa} != ${afinfoc}"; return 1; }
			test "${afinfoc}" != "${afinfom}" && { echo "Error: ${i:t}-ffmpeg.caf ${afinfoc} != ${afinfom}"; return 1; }
			test "${srcinfo}" != "${aifinfo}" && { echo "Error: ${i:t}-ffmpeg.aif ${srcinfo} != ${aifinfo}"; return 1; }
		}
		test "${srcinfo}" != "${cafinfo}" && { echo "Error: ${i:t}-ffmpeg.caf ${srcinfo} != ${cafinfo}"; return 1; }
		test "${srcinfo}" != "${movinfo}" && { echo "Error: ${i:t}-ffmpeg.mov ${srcinfo} != ${movinfo}"; return 1; }
		printf "${decorate}\n"
		printf "%s\n" "${i:t}"
		printf "Source:       %s\n" "${srcinfo}"
		test 0 -ne "${multichannel}" &&
		{
			## ffmpeg doesn't write CHAN for AIFF <= 2 channels
			## ffprobe will not see channel layout in this case
			printf "ffprobe(aif): %s\n" "${aifinfo}"
		}
		printf "ffprobe(caf): %s\n" "${cafinfo}"
		printf "ffprobe(mov): %s\n" "${movinfo}"
		test 0 -ne "${multichannel}" &&
		{
			## ffmpeg doesn't write CHAN for AIFF <= 2 channels
			## afinfo will not see layout for AIFF without chan
			printf "afinfo (aif): %s\n" "${afinfoa}"
		}
		printf "afinfo (caf): %s\n" "${afinfoc}"
		test 0 -ne "${multichannel}" &&
		{
			## ffmpeg doesn't use stsd v2 for MOV <= 2 channels
			## afinfo won't see or check the layout for stsd v1
			printf "afinfo (mov): %s\n" "${afinfom}"
		}
		printf "${decorate}\n"
	done
	printf "${decorate}\n"
} | less
