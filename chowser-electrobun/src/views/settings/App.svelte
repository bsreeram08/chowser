<script>
  let message = 'Hello Svelte!';
</script>

<div class="container">
  <h1>{message}</h1>
  <p>Svelte 5 is ready in the settings view.</p>
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    background: #1c1c1e;
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif;
    color: rgba(255, 255, 255, 0.87);
  }

  .container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    gap: 16px;
    padding: 20px;
  }

  h1 {
    font-size: 24px;
    font-weight: 700;
    margin: 0;
  }

  p {
    font-size: 14px;
    color: rgba(255, 255, 255, 0.6);
    margin: 0;
  }
</style>
