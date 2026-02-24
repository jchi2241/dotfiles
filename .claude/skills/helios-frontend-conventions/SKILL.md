---
name: helios-frontend-conventions
description: Use when writing or modifying React/TypeScript frontend code in the helios repo, including frontend/, fusion-design-system/, and single-js/.
---

# Helios Frontend Conventions

Stylistic rules for React/TypeScript code in the helios frontend. Follow these whenever writing or modifying frontend code.

## 1. No inline render functions

Don't define `renderX()` functions inside components. Extract them as separate components with typed props.

```tsx
// BAD: inline render function
function ParentComponent({ items }: Props) {
    const renderItem = (item: Item) => (
        <div>{item.name}</div>
    );

    return <div>{items.map(renderItem)}</div>;
}

// GOOD: separate component
function ItemRow({ item }: { item: Item }) {
    return <div>{item.name}</div>;
}

function ParentComponent({ items }: Props) {
    return (
        <div>
            {items.map((item) => (
                <ItemRow key={item.id} item={item} />
            ))}
        </div>
    );
}
```

## 2. No `&&` or ternary for conditional rendering

Use the if-block variable pattern instead of `&&` or `? :` in JSX.

**Why:**
- More consistent with the rest of the codebase (less mental overhead)
- More readable for long multi-line elements
- More easily extendable with additional logic
- Less error prone (ref: https://kentcdodds.com/blog/use-ternaries-rather-than-and-and-in-jsx)

```tsx
// BAD
return <div>{isVisible && <Modal />}</div>;
return <div>{isVisible ? <Modal /> : null}</div>;

// GOOD
let modal;
if (isVisible) {
    modal = <Modal />;
}
return <div>{modal}</div>;
```

Multiple conditionals:

```tsx
// BAD
return (
    <>
        {items.length > 0 && <ItemList items={items} />}
        {error && <ErrorMessage error={error} />}
    </>
);

// GOOD
let itemList;
if (items.length > 0) {
    itemList = <ItemList items={items} />;
}

let errorMessage;
if (error) {
    errorMessage = <ErrorMessage error={error} />;
}

return (
    <>
        {itemList}
        {errorMessage}
    </>
);
```

## Common Mistakes

- Using `&&` for "simple" one-liners -- the rule applies regardless of element complexity
- Defining `renderX` as arrow functions inside a component -- extract to a named component
- Using ternaries to toggle between two components -- use if/else blocks instead
