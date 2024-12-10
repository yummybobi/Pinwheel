import audio from '@ohos.multimedia.audio';
import { Permissions } from '@ohos.abilityAccessCtrl';
import { permissionHandler } from '../utils/PermissionHandler';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct Index {
  private permissions: Permissions[] = ['ohos.permission.MICROPHONE'];
  private audioCapturer: audio.AudioCapturer | null = null;
  @State decibel: number  = 0;
  @State angle: number = 0;
  @State maxDb: number = 0;
  private interval: number = 0;

  async aboutToAppear() {
    await this.requestPermissions();
  }

  private audioStreamInfo: audio.AudioStreamInfo = {
    samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
    channels: audio.AudioChannel.CHANNEL_2,
    sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
    encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
  };

  private audioCapturerInfo: audio.AudioCapturerInfo = {
    source: audio.SourceType.SOURCE_TYPE_MIC,
    capturerFlags: 0
  };

  private audioCapturerOptions: audio.AudioCapturerOptions = {
    streamInfo: this.audioStreamInfo,
    capturerInfo: this.audioCapturerInfo
  };

  async getAudioCapturer() {
    if (this.audioCapturer)
      return this.audioCapturer;
    this.audioCapturer = await audio.createAudioCapturer(this.audioCapturerOptions);
    return this.audioCapturer;
  }

  async requestPermissions() {
    try {
      await permissionHandler.requestPermissions(this.permissions);
    } catch {
      promptAction.showDialog({
        alignment: DialogAlignment.Center,
        title: 'Info',
        message: 'Please turn on mic in settings -> privacy -> microphone',
      })
    }
  }

  async startRecord() {
    this.maxDb = 0;
    const audioCapturer = await this.getAudioCapturer();
    this.audioCapturer = audioCapturer;
    audioCapturer.on('readData', (buffer) => {
      this.decibel = this.calculateDb(buffer);
      this.maxDb = this.maxDb < this.decibel ? this.decibel : this.maxDb;
    })
    this.audioCapturer.start();
  }

  async stopRecord() {
    await this.audioCapturer?.stop();
    await this.audioCapturer?.release();
    this.audioCapturer = null;
  }

  calculateDb(buffer: ArrayBuffer): number {
    let sum = 0;
    const bufferView = new DataView(buffer);
    const num = buffer.byteLength/2;

    for (let i = 0; i < buffer.byteLength; i += 2) {
      const sample = bufferView.getInt16(i, true)/32767;
      sum += sample * sample;
    }
    const rms = Math.sqrt(sum/num);
    const dB = 20 * Math.log10(rms/20e-6) - 20;
    return Math.max(Math.max(0, dB), dB);
  }

  async startRotate() {
    this.interval = setInterval(() => {
      this.angle += this.decibel/5;
    }, 20)
  }

  async stopRotate() {
    setTimeout(() => {
      this.angle = 0;
      this.decibel = 0;
      clearInterval(this.interval)
    }, 600)
  }

  build() {
    Row() {
      Flex({direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceAround,
        alignItems: ItemAlign.Center}) {
        Image($r("app.media.pinwheel"))
          .width(250)
          .aspectRatio(1)
          .rotate({ x: 0, y: 0, z: 1, centerX: '50%',
            centerY: '50%', angle: -this.angle })

        Row() {
          Button('Start')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .onClick(() => {
              this.startRecord();
              this.startRotate();
            })
            .width(100)
            .height(50)
            .backgroundColor('#7191F0')
            .border({width: 3, color: '#476ee6'})
            .clickEffect({level: ClickEffectLevel.HEAVY})

          Button('Stop')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .onClick(() => {
              this.stopRotate();
              this.stopRecord();
            })
            .width(100)
            .height(50)
            .backgroundColor('#b292d1')
            .border({width: 3, color: '#7634bf'})
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .padding(30)

        Text('Max dB reached: ' + this.maxDb.toFixed(0).toString())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#CD4A77')
      }
      .width('100%')
      .height('80%')
      .padding(20)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FCEECF')
    .justifyContent(FlexAlign.Center)
  }
}