# 🌌 The Single-Instance Expedition: Cover & Summary

Based on [paper.md](file:///home/xbill/nb2lite/paper.md), I've generated a premium cover image that captures the essence of "squeezing" a massive model into a tiny hardware footprint.

## 🖼️ Generated Cover Image

![Gemma MoE Cover Image](/home/xbill/nb2lite/cover.png)

---

## 📝 Paper Abstract: The Single-Instance Expedition

This paper chronicles the technical journey of optimizing **Gemma-4's 128-expert Mixture of Experts (MoE)** model (26B parameters) to run on the smallest, most cost-effective AWS accelerator: the **inf2.xlarge**.

### Key Technical Achievements:
- **Cost Reduction**: Achieved an **8.6x cost reduction**, moving from a $6.49/hr `inf2.24xlarge` to a **$0.76/hr** `inf2.xlarge`.
- **Int8 Squeeze**: Bypassed the "fp4 requirement" by identifying that the memory bottleneck was the replicated `lm_head`, not just the experts. Sharding and quantizing the head allowed the model to fit within 16GB of host RAM.
- **Slim Deployment**: Developed a deployment strategy that separates the 180GB peak compilation RAM requirement from the ~11GB runtime RSS, enabling 26B model inference on a box with only 16GB RAM.
- **Hardware-Software Synergy**: Leveraged AWS Neuron SDK features (and navigated its "pre-prod" pitfalls) to maintain numerical parity with the original fp32 weights.

### Conclusion:
The "Single-Instance Expedition" proves that massive MoE models can be hosted for the price of a coffee per day, provided one is willing to trade peak throughput (~6 tok/s) for extreme hosting efficiency.
