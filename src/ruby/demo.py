from csv import get_dialect


class IVR:
    def __init__(self):
        pass

    def play(self, text):
        print(f"> {text}")

    def play_bg(self, key):
        print(f"(> {key})")

    def sleep(self, millis):
        print(f"(sleeping for {millis} ms)")

    def get_dtmf(self, max_length):
        digits = input(f"Please enter up to {max_length} digits: ")
        return digits

    def hangup(self):
        print("(hanging up)")

class AnswerPhone(IVR):
    def run(self):
        self.bg_play('music')
        self.play("40 Grad im Schatten!")
        self.sleep(1000)
        self.bg_fadeout(1000)
        self.bg_stop()
        self.bg_play('music2')
        self.bg_fadein(1000)
        self.play("Bitte wähle eine Zahl zwischen 1 und 10.")
        answer = self.get_dtmf(3)
        self.play(f"Danke!")
        self.hangup()

a = AnswerPhone()
a.run()

# sox start.wav west.wav south.wav timeup.wav -t wav - | sox -m kscum.wav - -t wav out.wav
# sox out.wav out2.wav silence 1 0.1 1% 1 0.1 1% : newfile : restart
# sox -n -r 8000 -b 16 silence.wav synth 20 brownnoise vol -60dB
# sox out.wav -n spectrogram -r -y 64 -x 1024 -o out.png
# sox out2001.wav silence.wav out2002.wav silence.wav out2003.wav silence.wav out2004.wav out4.wav
# ffmpeg -i kscum-raw.wav -i out6.wav -filter_complex "[1:a]asplit=2[sc][mix];[0:a][sc]sidechaincompress=threshold=0.1:ratio=20:release=750[compr];[compr][mix]amix" out7.wav
# sudo apt install espeak mbrola-de*
# espeak -vmb-de6 -s 130 "Skarabäh-us! 30 Grad im Schatten! Die Sonne brennt und Ali die Ameise ist auf der Suche nach dem Schatz. Aber Vorsicht, es lauern überall Gefahren wie Spinnen und Fledermäuse."
# Hallo und herzlich Willkommen in der Hackschule. Leider können wir deinen Anruf gerade nicht persönlich entgegennehmen. Bitte gib deinen vierstelligen Code ein, um ein Spiel zu starten oder drücke viermal die 0 für ein zufälliges Spiel.