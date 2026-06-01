#!/bin/zsh
srcdirec="${HOME}/iCloudDrive/a.u.d.i.o/24000/24000"
dstdirec="${HOME}/Downloads/layouts"
builddir="${PWD}-build"
test -d  "${builddir}" || return 1
test -d  "${srcdirec}" || return 1
for i in "${srcdirec}"/*_AV_*.* "${srcdirec}"/*_kAu*.*
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
		lastexitstatus="${?}"
		echo "Error: ${i:t}-ffmpeg.aif" 1>&2
		return "${lastexitstatus}"
	}
	"${builddir}/ffmpeg" -v error -i "$i" -c pcm_s16le \
		-f caf -y "${dstdirec}/${i:t}-ffmpeg.caf"     ||
	{
		lastexitstatus="${?}"
		echo "Error: ${i:t}-ffmpeg.caf" 1>&2
		return "${lastexitstatus}"
	}
	"${builddir}/ffmpeg" -v error -i "$i" -c pcm_s16le \
		-f mov -y "${dstdirec}/${i:t}-ffmpeg.mov"     ||
	{
		lastexitstatus="${?}"
		echo "Error: ${i:t}-ffmpeg.mov" 1>&2
		return "${lastexitstatus}"
	}
done
{
	decorate="${(l:99::-:)}"
	printf "${decorate}\n"
	for i in "${srcdirec}"/*_AV_*.* "${srcdirec}"/*_kAu*.*
	do
		multichannel=1
		ffmovwritechan=0
		test -n "${ALL}" &&
		{
			## only test AIFF and CAF output files once
			## they stop using isom.c/ff_mov_write_chan
			## e.g. when stipulated by caller via ALL=1
			ffmovwritechan="$(printf "%d" "${ALL}")"
		}
		test "${i[-9,-1]}" = "MONO.FLAC" && multichannel=0
		test "${i[-12,-5]}" = "Binaural" && multichannel=0
		test "${i[-11,-1]}" = "STEREO.FLAC" && multichannel=0
		test "${i[-16,-5]}" = "MatrixStereo" && multichannel=0
		afinfoa=$(afinfo "${dstdirec}/${i:t}-ffmpeg.aif" | grep -o -e "Channel layout: .*" -e "no channel layout.")
		afinfoc=$(afinfo "${dstdirec}/${i:t}-ffmpeg.caf" | grep -o -e "Channel layout: .*" -e "no channel layout.")
		afinfom=$(afinfo "${dstdirec}/${i:t}-ffmpeg.mov" | grep -o -e "Channel layout: .*" -e "no channel layout.")
		srcinfo=$("${builddir}/ffprobe" -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 -i "${i}")
		aifinfo=$("${builddir}/ffprobe" -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 -i "${dstdirec}/${i:t}-ffmpeg.aif")
		cafinfo=$("${builddir}/ffprobe" -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 -i "${dstdirec}/${i:t}-ffmpeg.caf")
		movinfo=$("${builddir}/ffprobe" -v error -show_entries stream=channel_layout -of default=nk=1:nw=1 -i "${dstdirec}/${i:t}-ffmpeg.mov")
		movbmap=$("${builddir}/ffprobe" -v debug -i "${dstdirec}/${i:t}-ffmpeg.mov" 2>&1 | grep -F " chan: layout=65536 ")
		test 0 -lt "${multichannel}" &&
		test 0 -lt "${ffmovwritechan}" &&
		{
			test "${afinfoa}" != "${afinfoc}" && { echo "Error #1: ${i:t}-ffmpeg.aif ${afinfoa} != ${afinfoc}" 1>&2; return 1; }
			test "${afinfoc}" != "${afinfom}" && { echo "Error #2: ${i:t}-ffmpeg.caf ${afinfoc} != ${afinfom}" 1>&2; return 1; }
			test "${srcinfo}" != "${aifinfo}" && { echo "Error #3: ${i:t}-ffmpeg.aif ${srcinfo} != ${aifinfo}" 1>&2; return 1; }
		}
		test 0 -lt "${ffmovwritechan}" &&
		{
			test "${srcinfo}" != "${cafinfo}" && { echo "Error #4: ${i:t}-ffmpeg.caf ${srcinfo} != ${cafinfo}" 1>&2; return 1; }
		}
		true &&
		{
			test "${srcinfo}" != "${movinfo}" && { echo "Error #5: ${i:t}-ffmpeg.mov ${srcinfo} != ${movinfo}" 1>&2; return 1; }
		}
		printf "${decorate}\n"
		printf "%s\n" "${i:t}"
		true &&
		{
			printf "ffprobe(src): Channel layout: %s\n" "${srcinfo}"
		}
		test 0 -lt "${multichannel}" &&
		test 0 -lt "${ffmovwritechan}" && ## aiffenc/cafenc and/or bitmap code not yet updated
		{
			## ffmpeg doesn't write CHAN for AIFF <= 2 channels
			## ffprobe will not see channel layout in this case
			printf "ffprobe(aif): Channel layout: %s\n" "${aifinfo}"
		}
		test 0 -lt "${ffmovwritechan}" && ## aiffenc/cafenc and/or bitmap code not yet updated
		{
			printf "ffprobe(caf): Channel layout: %s\n" "${cafinfo}"
		}
		true &&
		{
			printf "ffprobe(mov): Channel layout: %s\n" "${movinfo}"
		}
		test 0 -lt "${multichannel}" &&
		test 0 -lt "${ffmovwritechan}" && ## aiffenc/cafenc and/or bitmap code not yet updated
		{
			## ffmpeg doesn't write CHAN for AIFF <= 2 channels
			## afinfo will not see layout for AIFF without CHAN
			printf "afinfo (aif): %s\n" "${afinfoa}"
		}
		test 0 -lt "${ffmovwritechan}" && ## aiffenc/cafenc and/or bitmap code not yet updated
		{
			printf "afinfo (caf): %s\n" "${afinfoc}"
		}
		test 0 -lt "${multichannel}" &&
		{
			test 0 -ge "${#movbmap}"       || ## MOV output does not use channel bitmap
			test 0 -lt "${ffmovwritechan}" && ## bitmap read/write code already updated
			{
				## ffmpeg doesn't use stsd v2 for MOV <= 2 channels
				## afinfo won't see or check the layout for stsd v1
				## unsure why but showing "no channel layout" seems pointless
				printf "afinfo (mov): %s\n" "${afinfom}"
			}
			test 0 -lt "${#movbmap}"       && ## MOV output file using a channel bitmap
			test 0 -ge "${ffmovwritechan}" && ## bitmap read/write code not yet updated
			{
				printf "afinfo (mov): kAudioChannelLayoutTag_UseChannelBitmap\n"
				printf "bitmap code not yet updated to match tag/descriptions\n"
			}
		}
		printf "${decorate}\n"
	done
	printf "${decorate}\n"
}  > "${dstdirec}/stdout.txt"
less "${dstdirec}/stdout.txt"
