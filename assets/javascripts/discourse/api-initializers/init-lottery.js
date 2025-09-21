import { withPluginApi } from "discourse/lib/plugin-api";
import LotteryFormModal from "../components/lottery-form-modal";

export default {
  name: "init-lottery",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (!siteSettings.lottery_enabled) {
      return;
    }
    
    withPluginApi("2.1.1", (api) => {
      const modal = container.lookup("service:modal");
      const currentUser = container.lookup("service:current-user");
      
      // 添加新主题按钮 - 仅在允许的分类中显示
      api.modifyClass("component:composer-editor", {
        pluginId: "lottery-composer",
        
        @action
        showLotteryForm() {
          const composer = this.composer;
          const topic = composer.get("topic");
          
          if (!topic || !topic.id) {
            return;
          }
          
          modal.show(LotteryFormModal, {
            model: {
              topic: topic
            }
          });
        }
      });
      
      // 添加工具栏按钮
      api.onToolbarCreate((toolbar) => {
        const composer = toolbar.composer;
        
        // 检查是否在允许的分类中
        if (!isLotteryAllowedCategory(composer, siteSettings)) {
          return;
        }
        
        // 检查是否有权限
        if (!canCreateLottery(currentUser, siteSettings)) {
          return;
        }
        
        toolbar.addButton({
          id: "lottery",
          group: "extras",
          icon: "gift",
          title: "lottery.button_title",
          perform: () => {
            // 检查是否是新主题
            if (!composer.get("creatingTopic")) {
              alert("只能在创建新主题时添加抽奖");
              return;
            }
            
            // 先保存主题草稿以获取 topic_id
            composer.save().then((result) => {
              if (result && result.responseJson && result.responseJson.id) {
                const topicId = result.responseJson.id;
                const topic = { id: topicId };
                
                modal.show(LotteryFormModal, {
                  model: { topic: topic }
                });
              }
            }).catch((error) => {
              console.error("保存主题失败:", error);
              alert("请先完善主题标题和内容");
            });
          }
        });
      });
      
      // 在主题页面显示抽奖信息
      api.modifyClass("component:topic-post", {
        pluginId: "lottery-topic-post",
        
        didInsertElement() {
          this._super(...arguments);
          this.addLotteryInfo();
        },
        
        addLotteryInfo() {
          const post = this.get("post");
          if (!post || post.get("post_number") !== 1) {
            return;
          }
          
          const topic = post.get("topic");
          if (!topic || !topic.lottery_data) {
            return;
          }
          
          // 动态插入抽奖信息组件
          this.appEvents.trigger("lottery:show-info", {
            topic: topic,
            lotteryData: topic.lottery_data
          });
        }
      });
    });
  }
};

function isLotteryAllowedCategory(composer, siteSettings) {
  const categoryIds = siteSettings.lottery_category_ids;
  
  if (!categoryIds || categoryIds.trim() === "") {
    return true; // 如果没有限制分类，则允许所有分类
  }
  
  const allowedIds = categoryIds.split("|").map(id => parseInt(id.trim()));
  const currentCategoryId = composer.get("categoryId");
  
  return allowedIds.includes(currentCategoryId);
}

function canCreateLottery(currentUser, siteSettings) {
  if (!currentUser) {
    return false;
  }
  
  const excludedGroups = siteSettings.lottery_excluded_groups.split("|");
  const userGroups = currentUser.groups?.map(g => g.name) || [];
  
  // 检查用户是否在排除的组中
  return !excludedGroups.some(group => userGroups.includes(group));
}
