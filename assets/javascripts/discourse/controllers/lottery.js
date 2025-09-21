import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class LotteryController extends Controller.extend(ModalFunctionality) {
  @service dialog;
  @service router;
  @service currentUser;
  
  @tracked isLoading = false;
  @tracked lotteryData = null;
  @tracked error = null;
  
  init() {
    super.init(...arguments);
    this.loadLotteryData();
  }
  
  @action
  async loadLotteryData() {
    if (!this.model?.topic?.id) return;
    
    this.isLoading = true;
    this.error = null;
    
    try {
      const result = await ajax(`/lottery/${this.model.topic.id}`);
      this.lotteryData = result.lottery;
    } catch (error) {
      console.error("加载抽奖数据失败:", error);
      this.error = "加载抽奖数据失败";
    } finally {
      this.isLoading = false;
    }
  }
  
  @action
  async refreshLotteryData() {
    await this.loadLotteryData();
  }
  
  @action
  showEditModal() {
    if (!this.canEdit) {
      this.dialog.alert("抽奖已锁定，无法编辑");
      return;
    }
    
    // 这里应该打开编辑模态框
    // 由于编辑功能复杂，暂时跳转到编辑页面
    this.router.transitionTo("editTopic", this.model.topic);
  }
  
  @action
  copyLotteryLink() {
    const url = `${window.location.origin}/t/${this.model.topic.slug}/${this.model.topic.id}`;
    
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(url).then(() => {
        this.dialog.alert("链接已复制到剪贴板");
      });
    } else {
      // 降级方案
      const textArea = document.createElement("textarea");
      textArea.value = url;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand("copy");
      document.body.removeChild(textArea);
      this.dialog.alert("链接已复制到剪贴板");
    }
  }
  
  @action
  shareLottery() {
    const url = `${window.location.origin}/t/${this.model.topic.slug}/${this.model.topic.id}`;
    const title = this.lotteryData?.title || "抽奖活动";
    const text = `${title} - 快来参与抽奖！`;
    
    if (navigator.share) {
      navigator.share({
        title: title,
        text: text,
        url: url
      }).catch(err => console.log("分享失败:", err));
    } else {
      // 降级到复制链接
      this.copyLotteryLink();
    }
  }
  
  @action
  async cancelLottery() {
    if (!this.lotteryData || this.lotteryData.status !== "running") {
      return;
    }
    
    const confirmed = await this.dialog.confirm({
      title: "取消抽奖",
      message: "确定要取消这个抽奖活动吗？此操作不可撤销。"
    });
    
    if (!confirmed) return;
    
    try {
      await ajax(`/lottery/${this.model.topic.id}/cancel`, {
        type: "POST"
      });
      
      this.dialog.alert("抽奖已取消");
      await this.refreshLotteryData();
      
    } catch (error) {
      console.error("取消抽奖失败:", error);
      popupAjaxError(error);
    }
  }
  
  get canEdit() {
    if (!this.lotteryData || !this.currentUser) return false;
    if (this.lotteryData.status !== "running") return false;
    if (this.lotteryData.user_id !== this.currentUser.id) return false;
    
    // 检查时间限制
    const drawTime = new Date(this.lotteryData.draw_time).getTime();
    const now = Date.now();
    const lockDelay = 30 * 60 * 1000; // 30分钟
    const lockTime = drawTime - lockDelay;
    
    return now < lockTime;
  }
  
  get canCancel() {
    if (!this.lotteryData || !this.currentUser) return false;
    if (this.lotteryData.status !== "running") return false;
    
    // 只有管理员或作者可以取消
    return this.currentUser.admin || 
           this.currentUser.moderator ||
           this.lotteryData.user_id === this.currentUser.id;
  }
  
  get timeUntilDraw() {
    if (!this.lotteryData?.draw_time) return null;
    
    const now = Date.now();
    const drawTime = new Date(this.lotteryData.draw_time).getTime();
    const diff = drawTime - now;
    
    if (diff <= 0) return "开奖时间已过";
    
    const seconds = Math.floor(diff / 1000);
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
  
  get lotteryTypeText() {
    if (!this.lotteryData) return "";
    
    if (this.lotteryData.lottery_type === "specified") {
      const floors = this.lotteryData.specified_floors || "";
      return `指定楼层 (${floors.split(',').join('、')}楼)`;
    }
    return "随机抽取";
  }
  
  get backupStrategyText() {
    if (!this.lotteryData) return "";
    
    return this.lotteryData.backup_strategy === "continue" ? 
      "人数不足时继续开奖" : "人数不足时取消活动";
  }
  
  get statusClass() {
    if (!this.lotteryData) return "";
    return `lottery-status-${this.lotteryData.status}`;
  }
  
  get statusText() {
    if (!this.lotteryData) return "";
    
    switch (this.lotteryData.status) {
      case "running": return "进行中";
      case "finished": return "已结束";
      case "cancelled": return "已取消";
      default: return "未知状态";
    }
  }
  
  get winnersFormatted() {
    if (!this.lotteryData?.winners_data) return [];
    
    return this.lotteryData.winners_data.map((winner, index) => ({
      rank: index + 1,
      username: winner.username,
      floor: winner.floor,
      user_id: winner.user_id
    }));
  }
}
