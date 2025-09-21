import { withPluginApi } from "discourse/lib/plugin-api";
import { h } from "virtual-dom";
import LotteryInfoCard from "../components/lottery-info-card";

export default {
  name: "lottery-topic-decorator",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (!siteSettings.lottery_enabled) {
      return;
    }
    
    withPluginApi("2.1.1", (api) => {
      // 装饰主题标题，添加抽奖标识
      api.decorateWidget("topic-title", (helper) => {
        const topic = helper.getModel();
        
        if (!topic || !topic.lottery_data) {
          return;
        }
        
        const status = topic.lottery_data.status;
        let iconName, className, title;
        
        switch (status) {
          case "running":
            iconName = "gift";
            className = "lottery-indicator running";
            title = "抽奖进行中";
            break;
          case "finished":
            iconName = "trophy";
            className = "lottery-indicator finished";
            title = "抽奖已结束";
            break;
          case "cancelled":
            iconName = "times-circle";
            className = "lottery-indicator cancelled";
            title = "抽奖已取消";
            break;
          default:
            return;
        }
        
        return h("span.lottery-topic-indicator", {
          className: className,
          title: title
        }, [
          h("i", { className: `fa fa-${iconName}` }),
          h("span.lottery-status-text", title)
        ]);
      });
      
      // 在主题列表中显示抽奖状态
      api.decorateWidget("topic-list-item", (helper) => {
        const topic = helper.getModel();
        
        if (!topic || !topic.lottery_data) {
          return;
        }
        
        const status = topic.lottery_data.status;
        let badgeClass, badgeText;
        
        switch (status) {
          case "running":
            badgeClass = "badge-notification lottery-running";
            badgeText = "抽奖中";
            break;
          case "finished":
            badgeClass = "badge-notification lottery-finished";
            badgeText = "已开奖";
            break;
          case "cancelled":
            badgeClass = "badge-notification lottery-cancelled";
            badgeText = "已取消";
            break;
          default:
            return;
        }
        
        return h("span", {
          className: badgeClass,
          title: `抽奖状态: ${badgeText}`
        }, badgeText);
      });
      
      // 在第一个帖子后插入抽奖信息卡片
      api.decorateWidget("post-contents", (helper) => {
        const post = helper.getModel();
        
        if (!post || post.post_number !== 1) {
          return;
        }
        
        const topic = post.topic;
        if (!topic || !topic.lottery_data) {
          return;
        }
        
        return helper.attach("lottery-info-widget", {
          topic: topic,
          lotteryData: topic.lottery_data
        });
      });
      
      // 创建抽奖信息小部件
      api.createWidget("lottery-info-widget", {
        html(attrs) {
          const { topic, lotteryData } = attrs;
          
          return h("div.lottery-info-wrapper", [
            h("div.lottery-separator"),
            this.attach("lottery-info-card-widget", {
              topic: topic,
              lotteryData: lotteryData
            })
          ]);
        }
      });
      
      // 创建抽奖信息卡片小部件
      api.createWidget("lottery-info-card-widget", {
        tagName: "div.lottery-info-card-widget",
        
        html(attrs) {
          const { lotteryData } = attrs;
          
          return [
            this.attach("lottery-header-widget", { lotteryData }),
            this.attach("lottery-content-widget", { lotteryData })
          ];
        }
      });
      
      api.createWidget("lottery-header-widget", {
        tagName: "div.lottery-header",
        
        html(attrs) {
          const { lotteryData } = attrs;
          const status = lotteryData.status;
          
          let iconName, statusText, statusClass;
          
          switch (status) {
            case "running":
              iconName = "clock";
              statusText = "抽奖进行中";
              statusClass = "status-running";
              break;
            case "finished":
              iconName = "trophy";
              statusText = "抽奖已结束";
              statusClass = "status-finished";
              break;
            case "cancelled":
              iconName = "times";
              statusText = "抽奖已取消";
              statusClass = "status-cancelled";
              break;
            default:
              iconName = "question";
              statusText = "未知状态";
              statusClass = "status-unknown";
          }
          
          return h("div", { className: `lottery-status ${statusClass}` }, [
            h("i", { className: `fa fa-${iconName} status-icon` }),
            h("span.status-text", statusText)
          ]);
        }
      });
      
      api.createWidget("lottery-content-widget", {
        tagName: "div.lottery-content",
        
        html(attrs) {
          const { lotteryData } = attrs;
          
          const elements = [
            h("h3.lottery-title", lotteryData.title),
            this.attach("lottery-details-widget", { lotteryData })
          ];
          
          if (lotteryData.status === "running") {
            elements.push(this.attach("lottery-countdown-widget", { lotteryData }));
          }
          
          if (lotteryData.status === "finished" && lotteryData.winners_data) {
            elements.push(this.attach("lottery-winners-widget", { 
              winnersData: lotteryData.winners_data 
            }));
          }
          
          return elements;
        }
      });
      
      api.createWidget("lottery-details-widget", {
        tagName: "div.lottery-details",
        
        html(attrs) {
          const { lotteryData } = attrs;
          
          const details = [
            this.detailItem("奖品说明", lotteryData.prize_description),
            this.detailItem("开奖时间", this.formatDateTime(lotteryData.draw_time)),
            this.detailItem("抽奖方式", this.getLotteryTypeText(lotteryData)),
            this.detailItem("获奖人数", `${lotteryData.winner_count}人`),
            this.detailItem("参与门槛", `${lotteryData.min_participants}人`),
            this.detailItem("后备策略", this.getBackupStrategyText(lotteryData))
          ];
          
          if (lotteryData.image_url) {
            details.unshift(
              h("div.detail-item", [
                h("span.detail-label", "奖品图片:"),
                h("div.lottery-image", [
                  h("img.prize-image", {
                    src: lotteryData.image_url,
                    alt: "奖品图片"
                  })
                ])
              ])
            );
          }
          
          if (lotteryData.additional_notes) {
            details.push(this.detailItem("补充说明", lotteryData.additional_notes));
          }
          
          return details;
        },
        
        detailItem(label, value) {
          return h("div.detail-item", [
            h("span.detail-label", `${label}:`),
            h("span.detail-value", value)
          ]);
        },
        
        formatDateTime(dateStr) {
          if (!dateStr) return "";
          const date = new Date(dateStr);
          return date.toLocaleString("zh-CN", {
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit"
          });
        },
        
        getLotteryTypeText(lotteryData) {
          if (lotteryData.lottery_type === "specified") {
            const floors = lotteryData.specified_floors || "";
            return `指定楼层 (${floors.split(',').join('、')}楼)`;
          }
          return "随机抽取";
        },
        
        getBackupStrategyText(lotteryData) {
          return lotteryData.backup_strategy === "continue" ? 
            "人数不足时继续开奖" : "人数不足时取消活动";
        }
      });
      
      api.createWidget("lottery-countdown-widget", {
        tagName: "div.lottery-countdown",
        
        buildKey(attrs) {
          return `lottery-countdown-${attrs.lotteryData.draw_time}`;
        },
        
        html(attrs) {
          const { lotteryData } = attrs;
          const drawTime = new Date(lotteryData.draw_time).getTime();
          const now = Date.now();
          const timeRemaining = drawTime - now;
          
          if (timeRemaining <= 0) {
            return h("div.countdown-item", [
              h("span.countdown-label", "状态:"),
              h("span.countdown-value.expired", "开奖时间已过")
            ]);
          }
          
          return h("div.countdown-item", [
            h("span.countdown-label", "距离开奖:"),
            h("span.countdown-value", this.formatTimeRemaining(timeRemaining))
          ]);
        },
        
        formatTimeRemaining(milliseconds) {
          const seconds = Math.floor(milliseconds / 1000);
          const minutes = Math.floor(seconds / 60);
          const hours = Math.floor(minutes / 60);
          const days = Math.floor(hours / 24);
          
          if (days > 0) {
            return `${days}天${hours % 24}小时`;
          } else if (hours > 0) {
            return `${hours}小时${minutes % 60}分钟`;
          } else if (minutes > 0) {
            return `${minutes}分钟${seconds % 60}秒`;
          } else {
            return `${seconds}秒`;
          }
        }
      });
      
      api.createWidget("lottery-winners-widget", {
        tagName: "div.lottery-winners",
        
        html(attrs) {
          const { winnersData } = attrs;
          
          if (!winnersData || winnersData.length === 0) {
            return h("div.no-winners", "暂无中奖信息");
          }
          
          const winnersList = winnersData.map((winner, index) => {
            return h("li.winner-item", [
              h("span.winner-rank", `${index + 1}.`),
              h("span.winner-username", `@${winner.username}`),
              h("span.winner-floor", `(${winner.floor}楼)`)
            ]);
          });
          
          return [
            h("h4.winners-title", [
              h("i.fa.fa-trophy"),
              " 中奖名单"
            ]),
            h("ul.winners-list", winnersList)
          ];
        }
      });
    });
  }
};
