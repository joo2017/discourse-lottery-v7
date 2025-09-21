import { withPluginApi } from "discourse/lib/plugin-api";
import LotteryFormModal from "../components/lottery-form-modal";

export default {
  name: "lottery-topic-template",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (!siteSettings.lottery_enabled) {
      return;
    }
    
    withPluginApi("2.1.1", (api) => {
      const modal = container.lookup("service:modal");
      const currentUser = container.lookup("service:current-user");
      
      // 在特定分类创建主题时自动显示抽奖表单选项
      api.modifyClass("route:new-topic", {
        pluginId: "lottery-new-topic",
        
        setupController(controller, model) {
          this._super(controller, model);
          
          // 检查是否在抽奖分类中
          const categoryId = controller.get("model.category.id");
          if (this.isLotteryCategory(categoryId)) {
            // 延迟显示提示，让用户先看到正常的创建界面
            setTimeout(() => {
              this.showLotteryPrompt(controller);
            }, 1000);
          }
        },
        
        isLotteryCategory(categoryId) {
          const allowedIds = siteSettings.lottery_category_ids;
          if (!allowedIds || allowedIds.trim() === "") {
            return false;
          }
          
          const allowed = allowedIds.split("|").map(id => parseInt(id.trim()));
          return allowed.includes(categoryId);
        },
        
        showLotteryPrompt(controller) {
          const dialog = container.lookup("service:dialog");
          
          dialog.confirm({
            title: "创建抽奖活动",
            message: "您正在抽奖分类中创建主题，是否需要添加抽奖功能？",
            confirmButtonLabel: "添加抽奖",
            cancelButtonLabel: "普通主题",
            didConfirm: () => {
              this.openLotteryForm(controller);
            }
          });
        },
        
        openLotteryForm(controller) {
          // 提示用户先保存主题
          dialog.alert({
            message: "请先填写主题标题和内容，然后保存主题后再设置抽奖。",
            didDismiss: () => {
              // 可以在这里添加自动聚焦到标题输入框的逻辑
              const titleInput = document.querySelector("#reply-title");
              if (titleInput) {
                titleInput.focus();
              }
            }
          });
        }
      });
      
      // 在编辑器中添加抽奖助手
      api.modifyClass("component:d-editor", {
        pluginId: "lottery-editor-helper",
        
        @action
        insertLotteryTemplate() {
          const template = `
## 🎉 抽奖活动

**活动说明：** 请在此描述您的抽奖活动

**参与方式：** 在本帖下方回复即可参与抽奖

**活动规则：**
- 每人限参与一次
- 重复回复以最早回复为准
- 严禁小号参与

**开奖方式：** 系统将自动开奖并公布结果

---

> 💡 提示：发布主题后，点击编辑器工具栏中的"🎁"按钮来设置具体的抽奖参数
          `;
          
          this.insertText(template);
        }
      });
      
      // 添加编辑器工具栏按钮
      api.addToolbarPopupMenuOptionsCallback(() => {
        const composer = container.lookup("service:composer");
        
        if (!composer.model || !this.canShowLotteryButton(composer.model)) {
          return {};
        }
        
        return {
          icon: "gift",
          label: "插入抽奖模板",
          action: () => {
            const editor = container.lookup("component:d-editor");
            if (editor && typeof editor.insertLotteryTemplate === 'function') {
              editor.insertLotteryTemplate();
            }
          }
        };
      });
    });
  },
  
  canShowLotteryButton(composerModel) {
    const siteSettings = container.lookup("service:site-settings");
    
    if (!composerModel.creatingTopic) {
      return false;
    }
    
    // 检查分类限制
    const allowedIds = siteSettings.lottery_category_ids;
    if (allowedIds && allowedIds.trim() !== "") {
      const allowed = allowedIds.split("|").map(id => parseInt(id.trim()));
      const categoryId = composerModel.categoryId;
      return allowed.includes(categoryId);
    }
    
    return true;
  }
};
