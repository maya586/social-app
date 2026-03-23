import http from '@ohos.net.http';
import router from '@ohos.router';
import hilog from '@ohos.hilog';

const API_URL = 'http://23.95.170.176:8080/api/v1';

@Entry
@Component
struct LoginPage {
  @State phone: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  async login() {
    if (!this.phone || !this.password) {
      this.errorMessage = '请输入手机号和密码';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(`${API_URL}/auth/login`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: {
          phone: this.phone,
          password: this.password
        }
      });

      if (response.responseCode === 200) {
        let result = JSON.parse(response.result as string);
        if (result.code === 200) {
          router.replaceUrl({
            url: 'pages/MainPage'
          });
        } else {
          this.errorMessage = result.message || '登录失败';
        }
      } else {
        this.errorMessage = '网络错误，请重试';
      }
      httpRequest.destroy();
    } catch (error) {
      hilog.error(0x0000, 'Login', 'Error: %{public}s', JSON.stringify(error));
      this.errorMessage = '登录失败，请检查网络';
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      Image($r('app.media.app_icon'))
        .width(80)
        .height(80)
        .margin({ top: 80, bottom: 20 })

      Text('社交应用')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a73e8')
        .margin({ bottom: 40 })

      TextInput({ placeholder: '手机号' })
        .width('80%')
        .height(50)
        .type(InputType.PhoneNumber)
        .onChange((value: string) => {
          this.phone = value;
        })
        .margin({ bottom: 16 })

      TextInput({ placeholder: '密码' })
        .width('80%')
        .height(50)
        .type(InputType.Password)
        .onChange((value: string) => {
          this.password = value;
        })
        .margin({ bottom: 24 })

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor('#f44336')
          .margin({ bottom: 16 })
      }

      Button(this.isLoading ? '登录中...' : '登录')
        .width('80%')
        .height(50)
        .enabled(!this.isLoading)
        .onClick(() => this.login())
        .backgroundColor('#1a73e8')
        .borderRadius(25)

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}