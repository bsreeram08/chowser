import { cn } from "@/lib/utils"
/* eslint-disable @typescript-eslint/no-unused-vars */
import { RiLoaderLine } from "@remixicon/react"

function Spinner({ className, ...props }: React.ComponentProps<"svg">) {
  const { children, ...rest } = props as any;
  return (
    <RiLoaderLine role="status" aria-label="Loading" className={cn("size-4 animate-spin", className)} {...rest} />
  )
}

export { Spinner }
