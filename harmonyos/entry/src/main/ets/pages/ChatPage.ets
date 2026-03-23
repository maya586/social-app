import router from '@ohos.router';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';

const API_URL = 'http://23.95.170.176:8080/api/v1';

interface Message {
  id: string;
  sender_id: string;
  content: string;
  type: string;
  created_at: string;
}

@Entry
@Component
struct ChatPage {
  @State messages: Message[] = [];
  @State inputText: string = '';
  @State isLoading: boolean = true;
  @State conversationId: string = '';
  @State otherUserName: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>;
    this.conversationId = params.conversationId || '';
    this.loadMessages();
  }

  async loadMessages() {
    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(
        `${API_URL}/messages/conversation/${this.conversationId}?limit=50`,
        { method: http.RequestMethod.GET }
      );

      if (response.responseCode === 200) {
        let result = JSON.parse(response.result as string);
        if (result.code === 200) {
          this.messages = result.data || [];
        }
      }
      httpRequest.destroy();
    } catch (error) {
      hilog.error(0x0000, 'ChatPage', 'Error: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  async sendMessage() {
    if (!this.inputText.trim()) return;

    let content = this.inputText;
    this.inputText = '';

    try {
      let httpRequest = http.createHttp();
      await httpRequest.request(`${API_URL}/messages`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: {
          conversation_id: this.conversationId,
          type: 'text',
          content: content
        }
      });
      httpRequest.destroy();
      
      this.loadMessages();
    } catch (error) {
      hilog.error(0x0000, 'ChatPage', 'Send error: %{public}s', JSON.stringify(error));
    }
  }

  formatTime(dateStr: string): string {
    try {
      let date = new Date(dateStr);
      return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    } catch {
      return '';
    }
  }

  build() {
    Column() {
      Row() {
        Button('<')
          .backgroundColor(Color.Transparent)
          .fontColor('#1a73e8')
          .onClick(() => router.back())

        Text(this.otherUserName || '聊天')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })

      List({ scroller: this.scroller }) {
        ForEach(this.messages, (item: Message) => {
          ListItem() {
            Row() {
              if (item.sender_id === 'current_user_id') {
                Blank()
                Column() {
                  Text(item.content)
                    .fontSize(16)
                    .padding(12)
                    .backgroundColor('#1a73e8')
                    .fontColor(Color.White)
                    .borderRadius(16)

                  Text(this.formatTime(item.created_at))
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.End)
              } else {
                Column() {
                  Text(item.content)
                    .fontSize(16)
                    .padding(12)
                    .backgroundColor('#f0f0f0')
                    .borderRadius(16)

                  Text(this.formatTime(item.created_at))
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#f5f5f5')

      Row() {
        TextInput({ placeholder: '输入消息', text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#f0f0f0')
          .borderRadius(20)
          .onChange((value: string) => {
            this.inputText = value;
          })

        Button('发送')
          .height(40)
          .backgroundColor('#1a73e8')
          .margin({ left: 8 })
          .onClick(() => this.sendMessage())
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}