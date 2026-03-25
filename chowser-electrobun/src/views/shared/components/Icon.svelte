<script lang="ts">
  interface IconProps {
    size?: number;
    color?: string;
  }

  let { size = 20, color = 'currentColor' } = $props<IconProps>();
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke={color}
  stroke-width="2"
  stroke-linecap="round"
  stroke-linejoin="round"
  style="display: inline-block; vertical-align: middle;"
>
  <slot />
</svg>

<style>
  svg {
    flex-shrink: 0;
  }
</style>
