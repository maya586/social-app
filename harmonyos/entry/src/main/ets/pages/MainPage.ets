import router from '@ohos.router';
import http from '@ohos.net.http';
import hilog from '@ohos.hilog';

const API_URL = 'http://23.95.170.176:8080/api/v1';

interface Conversation {
  id: string;
  other_user_name: string;
  last_message: string;
  unread_count: number;
}

@Entry
@Component
struct MainPage {
  @State conversations: Conversation[] = [];
  @State currentIndex: number = 0;
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadConversations();
  }

  async loadConversations() {
    try {
      let httpRequest = http.createHttp();
      let response = await httpRequest.request(`${API_URL}/conversations`, {
        method: http.RequestMethod.GET
      });

      if (response.responseCode === 200) {
        let result = JSON.parse(response.result as string);
        if (result.code === 200) {
          this.conversations = result.data || [];
        }
      }
      httpRequest.destroy();
    } catch (error) {
      hilog.error(0x0000, 'MainPage', 'Error: %{public}s', JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  @Builder
  conversationList() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(50)
          .height(50)
          .color('#1a73e8')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.conversations.length === 0) {
      Column() {
        Text('暂无会话')
          .fontSize(16)
          .fontColor('#999999')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        ForEach(this.conversations, (item: Conversation) => {
          ListItem() {
            Row() {
              Stack() {
                Circle()
                  .width(50)
                  .height(50)
                  .fill('#1a73e8')
                Text(item.other_user_name ? item.other_user_name.charAt(0) : '?')
                  .fontSize(20)
                  .fontColor(Color.White)
              }

              Column() {
                Text(item.other_user_name || '未知用户')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(item.last_message || '')
                  .fontSize(14)
                  .fontColor('#999999')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12, right: 12 })

              if (item.unread_count > 0) {
                Text(item.unread_count.toString())
                  .fontSize(12)
                  .fontColor(Color.White)
                  .backgroundColor('#f44336')
                  .borderRadius(10)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              }
            }
            .width('100%')
            .padding(12)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/ChatPage',
                params: { conversationId: item.id }
              });
            })
          }
        })
      }
      .width('100%')
      .height('100%')
      .divider({ strokeWidth: 1, color: '#f0f0f0', startMargin: 74, endMargin: 0 })
    }
  }

  @Builder
  contactsList() {
    Column() {
      Text('联系人')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .padding(16)
      
      Text('功能开发中...')
        .fontSize(16)
        .fontColor('#999999')
        .margin({ top: 100 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  profilePage() {
    Column() {
      Text('我的')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .padding(16)
      
      Button('退出登录')
        .width('80%')
        .height(50)
        .backgroundColor('#f44336')
        .onClick(() => {
          router.replaceUrl({ url: 'pages/LoginPage' });
        })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() {
          this.conversationList()
        }
        .tabBar('消息')

        TabContent() {
          this.contactsList()
        }
        .tabBar('联系人')

        TabContent() {
          this.profilePage()
        }
        .tabBar('我的')
      }
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}